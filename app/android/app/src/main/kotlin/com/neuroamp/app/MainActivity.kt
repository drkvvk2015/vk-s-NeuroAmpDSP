package com.neuroamp.app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.AudioTrack
import android.util.Log
import com.neuroamp.app.dsp.DspProcessor
import com.neuroamp.app.dsp.DspConfig
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.ArrayDeque
import kotlin.math.min
import kotlin.math.PI
import kotlin.math.sin

class MainActivity : FlutterActivity(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var rotationSensor: Sensor? = null
    private var yawDegrees: Double = 0.0
    private var dspProcessor: DspProcessor? = null
    @Volatile
    private var currentDspConfig: DspConfig = DspConfig()
    @Volatile
    private var realtimeDemoRunning: Boolean = false
    private var realtimeDemoThread: Thread? = null
    private var realtimeAudioTrack: AudioTrack? = null
    @Volatile
    private var filePlaybackRunning: Boolean = false
    private var filePlaybackThread: Thread? = null
    private var fileAudioTrack: AudioTrack? = null
    @Volatile
    private var outputGainLinear: Float = 1.0f
    @Volatile
    private var lastPlaybackError: String = "idle"
    @Volatile
    private var lastInputRms: Float = 0.0f
    @Volatile
    private var lastOutputRms: Float = 0.0f

    companion object {
        private const val CHANNEL = "com.neuroamp/dsp"
        private const val TAG = "NeuroAmpMainActivity"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

        // Initialize DSP processor
        try {
            dspProcessor = DspProcessor()
            val ok = dspProcessor?.initialize(48000) ?: false
            if (!ok) {
                dspProcessor = null
                Log.w(TAG, "Native DSP initialize failed; running without DSP")
            }
        } catch (e: Throwable) {
            // DSP unavailable; continue with sensor-only mode
            dspProcessor = null
            Log.w(TAG, "Native DSP unavailable", e)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getHeadTrackingYaw" -> result.success(yawDegrees)
                    "getDspEngineVersion" -> result.success(getDspEngineVersion())
                    "processAudioFrame" -> {
                        val samples = call.argument<List<Number>>("samples")
                        if (samples == null) {
                            result.error("invalid_args", "Missing samples payload", null)
                        } else {
                            val processor = dspProcessor
                            if (processor == null) {
                                result.error("dsp_unavailable", "DSP processor not initialized", null)
                                return@setMethodCallHandler
                            }

                            val floatSamples = samples.map { it.toFloat() }.toFloatArray()
                            try {
                                val processedSamples = processor.processFrame(
                                    floatSamples,
                                    currentDspConfig
                                )
                                result.success(processedSamples.map { it.toDouble() })
                            } catch (e: Throwable) {
                                Log.e(TAG, "processAudioFrame failed", e)
                                result.success(samples.map { it.toDouble() })
                            }
                        }
                    }
                    "setDspConfig" -> {
                        val config = call.argument<Map<String, Any?>>("config")
                        if (config == null) {
                            result.success(false)
                        } else {
                            currentDspConfig = configFromMap(config)
                            result.success(true)
                        }
                    }
                    "initializeDsp" -> {
                        val sampleRate = call.argument<Int>("sampleRate") ?: 48000
                        val success = try {
                            dspProcessor?.initialize(sampleRate) ?: false
                        } catch (_: Throwable) {
                            false
                        }
                        result.success(success)
                    }
                    "releaseDsp" -> {
                        val success = try {
                            stopRealtimeDspDemo()
                            stopFileDspPlayback()
                            dspProcessor?.release() ?: false
                        } catch (_: Throwable) {
                            false
                        }
                        result.success(success)
                    }
                    "startRealtimeDspDemo" -> result.success(startRealtimeDspDemo())
                    "stopRealtimeDspDemo" -> result.success(stopRealtimeDspDemo())
                    "isRealtimeDspDemoRunning" -> result.success(realtimeDemoRunning)
                    "setOutputGainDb" -> {
                        val gainDb = (call.argument<Number>("gainDb") ?: 0.0).toDouble().toFloat()
                        outputGainLinear = dbToLinear(gainDb.coerceIn(-18.0f, 18.0f))
                        result.success(true)
                    }
                    "getPlaybackStatus" -> {
                        result.success(
                            mapOf(
                                "realtimeRunning" to realtimeDemoRunning,
                                "fileRunning" to filePlaybackRunning,
                                "dspReady" to (dspProcessor != null),
                                "lastError" to lastPlaybackError,
                                "outputGainLinear" to outputGainLinear,
                                "inputRms" to lastInputRms,
                                "outputRms" to lastOutputRms,
                            ),
                        )
                    }
                    "startFileDspPlayback" -> {
                        val filePath = call.argument<String>("filePath")
                        if (filePath.isNullOrBlank()) {
                            result.success(false)
                        } else {
                            result.success(startFileDspPlayback(filePath))
                        }
                    }
                    "stopFileDspPlayback" -> result.success(stopFileDspPlayback())
                    "isFileDspPlaybackRunning" -> result.success(filePlaybackRunning)
                    else -> result.notImplemented()
                }
            }
    }

    override fun onResume() {
        super.onResume()
        rotationSensor?.also {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    override fun onPause() {
        super.onPause()
        sensorManager.unregisterListener(this)
        stopRealtimeDspDemo()
        stopFileDspPlayback()
    }

    override fun onDestroy() {
        stopRealtimeDspDemo()
        stopFileDspPlayback()
        super.onDestroy()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_ROTATION_VECTOR) {
            return
        }

        val rotationMatrix = FloatArray(9)
        SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)

        val orientation = FloatArray(3)
        SensorManager.getOrientation(rotationMatrix, orientation)

        yawDegrees = Math.toDegrees(orientation[0].toDouble())
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // No-op.
    }

    private fun configFromMap(config: Map<String, Any?>): DspConfig {
        val rawEqBands = config["eqBands"] as? List<*>
        val eqBands = rawEqBands
            ?.mapNotNull { entry ->
                val map = entry as? Map<*, *> ?: return@mapNotNull null
                val frequencyHz = (map["frequencyHz"] as? Number)?.toDouble() ?: return@mapNotNull null
                val gainDb = (map["gainDb"] as? Number)?.toFloat() ?: return@mapNotNull null
                val q = (map["q"] as? Number)?.toFloat() ?: return@mapNotNull null
                com.neuroamp.app.dsp.EqBand(frequencyHz = frequencyHz, gainDb = gainDb, q = q)
            }
            ?: emptyList()

        return DspConfig(
            eqBands = eqBands,
            bassBoostDb = (config["bassBoost"] as? Number)?.toFloat() ?: 0f,
            spatialWidth = (config["spatialWidth"] as? Number)?.toFloat() ?: 0.25f,
            peakLimiterDb = (config["peakLimiterDb"] as? Number)?.toFloat() ?: -1f,
            convolverEnabled = config["convolverEnabled"] as? Boolean ?: false,
        )
    }

    private external fun nativeDspVersion(): String

    private fun getDspEngineVersion(): String {
        return try {
            nativeDspVersion()
        } catch (_: UnsatisfiedLinkError) {
            "dsp-native-unavailable"
        }
    }

    private fun startRealtimeDspDemo(): Boolean {
        if (realtimeDemoRunning) {
            return true
        }

        val processor = ensureDspProcessorReady()
        if (processor == null) {
            lastPlaybackError = "DSP processor unavailable"
            return false
        }

        stopFileDspPlayback()
        val sampleRate = 48000
        val frameSize = 512
        val minBuffer = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )

        if (minBuffer == AudioTrack.ERROR || minBuffer == AudioTrack.ERROR_BAD_VALUE) {
            Log.e(TAG, "Invalid min buffer size for realtime demo")
            lastPlaybackError = "Invalid AudioTrack min buffer size"
            return false
        }

        val desiredBuffer = maxOf(minBuffer, frameSize * 8)
        val track = AudioTrack(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build(),
            AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .build(),
            desiredBuffer,
            AudioTrack.MODE_STREAM,
            AudioManager.AUDIO_SESSION_ID_GENERATE,
        )

        if (track.state != AudioTrack.STATE_INITIALIZED) {
            Log.e(TAG, "AudioTrack failed to initialize")
            track.release()
            lastPlaybackError = "AudioTrack initialization failed"
            return false
        }

        realtimeAudioTrack = track
        realtimeDemoRunning = true
        lastPlaybackError = "none"

        realtimeDemoThread = Thread {
            val input = FloatArray(frameSize)
            val outputShort = ShortArray(frameSize)
            var sampleIndex = 0L

            try {
                track.play()
                while (realtimeDemoRunning) {
                    val localConfig = currentDspConfig
                    for (i in 0 until frameSize) {
                        val t = sampleIndex.toDouble() / sampleRate.toDouble()
                        val base = sin(2.0 * PI * 110.0 * t) * 0.35
                        val harmonic = sin(2.0 * PI * 220.0 * t) * 0.2
                        val sparkle = sin(2.0 * PI * 1760.0 * t) * 0.08
                        input[i] = (base + harmonic + sparkle).toFloat().coerceIn(-1.0f, 1.0f)
                        sampleIndex++
                    }

                    val processed = try {
                        processor.processFrame(input, localConfig)
                    } catch (e: Throwable) {
                        Log.e(TAG, "Realtime DSP processing failed", e)
                        input
                    }

                    for (i in 0 until frameSize) {
                        val amplified = (processed[i] * outputGainLinear).coerceIn(-1.0f, 1.0f)
                        val scaled = (amplified * Short.MAX_VALUE).toInt()
                        outputShort[i] = scaled.toShort()
                    }

                    val written = track.write(outputShort, 0, outputShort.size)
                    if (written < 0) {
                        Log.e(TAG, "AudioTrack write failed with code: $written")
                        lastPlaybackError = "AudioTrack write failed ($written)"
                        break
                    }
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Realtime DSP demo thread crashed", e)
                lastPlaybackError = "Realtime DSP thread crashed: ${e.message}"
            } finally {
                try {
                    track.pause()
                    track.flush()
                    track.stop()
                } catch (_: Throwable) {
                }
            }
        }.also {
            it.name = "NeuroAmpRealtimeDsp"
            it.start()
        }

        return true
    }

    private fun stopRealtimeDspDemo(): Boolean {
        if (!realtimeDemoRunning && realtimeDemoThread == null && realtimeAudioTrack == null) {
            return true
        }

        realtimeDemoRunning = false

        try {
            realtimeDemoThread?.join(500)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }

        realtimeDemoThread = null

        realtimeAudioTrack?.let { track ->
            try {
                track.pause()
                track.flush()
                track.stop()
            } catch (_: Throwable) {
            } finally {
                try {
                    track.release()
                } catch (_: Throwable) {
                }
            }
        }
        realtimeAudioTrack = null

        return true
    }

    private data class WavInfo(
        val channels: Int,
        val sampleRate: Int,
        val bitsPerSample: Int,
        val dataOffset: Long,
        val dataSize: Long,
    )

    private fun startFileDspPlayback(filePath: String): Boolean {
        if (filePlaybackRunning) {
            return true
        }

        stopRealtimeDspDemo()

        val wavInfo = try {
            parseWavInfo(filePath)
        } catch (e: Throwable) {
            Log.e(TAG, "WAV probe failed for file: $filePath", e)
            null
        }

        return if (wavInfo != null) {
            startWavFileDspPlayback(filePath, wavInfo)
        } else {
            startCompressedFileDspPlayback(filePath)
        }
    }

    private fun startWavFileDspPlayback(filePath: String, wavInfo: WavInfo): Boolean {
        val processor = ensureDspProcessorReady()
        if (processor == null) {
            lastPlaybackError = "DSP processor unavailable"
            return false
        }

        if (wavInfo.bitsPerSample != 16) {
            Log.e(TAG, "Unsupported WAV bit depth: ${wavInfo.bitsPerSample}. Only PCM16 is supported.")
            lastPlaybackError = "Unsupported WAV bit depth: ${wavInfo.bitsPerSample}"
            return false
        }
        if (wavInfo.channels != 1 && wavInfo.channels != 2) {
            Log.e(TAG, "Unsupported WAV channels: ${wavInfo.channels}. Only mono/stereo is supported.")
            lastPlaybackError = "Unsupported WAV channel count: ${wavInfo.channels}"
            return false
        }

        val frameSize = 512
        val minBuffer = AudioTrack.getMinBufferSize(
            wavInfo.sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuffer == AudioTrack.ERROR || minBuffer == AudioTrack.ERROR_BAD_VALUE) {
            Log.e(TAG, "Invalid min buffer size for WAV playback")
            lastPlaybackError = "Invalid AudioTrack min buffer size for WAV"
            return false
        }

        val desiredBuffer = maxOf(minBuffer, frameSize * 8)
        val track = AudioTrack(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build(),
            AudioFormat.Builder()
                .setSampleRate(wavInfo.sampleRate)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .build(),
            desiredBuffer,
            AudioTrack.MODE_STREAM,
            AudioManager.AUDIO_SESSION_ID_GENERATE,
        )

        if (track.state != AudioTrack.STATE_INITIALIZED) {
            Log.e(TAG, "AudioTrack failed to initialize for WAV playback")
            track.release()
            lastPlaybackError = "AudioTrack initialization failed for WAV"
            return false
        }

        fileAudioTrack = track
        filePlaybackRunning = true
        lastPlaybackError = "none"

        filePlaybackThread = Thread {
            val bytesPerSample = 2
            val bytesPerFrame = wavInfo.channels * bytesPerSample
            val byteBuffer = ByteArray(frameSize * bytesPerFrame)
            val input = FloatArray(frameSize)
            val outputShort = ShortArray(frameSize)

            try {
                RandomAccessFile(filePath, "r").use { raf ->
                    raf.seek(wavInfo.dataOffset)
                    var remaining = wavInfo.dataSize
                    track.play()

                    while (filePlaybackRunning && remaining > 0) {
                        val request = min(byteBuffer.size.toLong(), remaining).toInt()
                        val read = raf.read(byteBuffer, 0, request)
                        if (read <= 0) {
                            break
                        }
                        remaining -= read.toLong()

                        val monoSamples = read / bytesPerFrame
                        for (i in 0 until monoSamples) {
                            val frameOffset = i * bytesPerFrame
                            input[i] = if (wavInfo.channels == 1) {
                                pcm16ToFloat(byteBuffer[frameOffset], byteBuffer[frameOffset + 1])
                            } else {
                                val left = pcm16ToFloat(byteBuffer[frameOffset], byteBuffer[frameOffset + 1])
                                val right = pcm16ToFloat(byteBuffer[frameOffset + 2], byteBuffer[frameOffset + 3])
                                ((left + right) * 0.5f).coerceIn(-1.0f, 1.0f)
                            }
                        }

                        val frameIn = if (monoSamples == frameSize) {
                            input
                        } else {
                            input.copyOf(monoSamples)
                        }

                        val written = processFrameAndWrite(
                            processor = processor,
                            input = frameIn,
                            outputShort = outputShort,
                            track = track,
                            label = "WAV",
                        )
                        if (written < 0) {
                            Log.e(TAG, "AudioTrack write failed during WAV playback: $written")
                            lastPlaybackError = "WAV playback write failed ($written)"
                            break
                        }
                    }
                }
            } catch (e: Throwable) {
                Log.e(TAG, "File DSP playback crashed", e)
                lastPlaybackError = "WAV DSP thread crashed: ${e.message}"
            } finally {
                filePlaybackRunning = false
                try {
                    track.pause()
                    track.flush()
                    track.stop()
                } catch (_: Throwable) {
                }
            }
        }.also {
            it.name = "NeuroAmpFileDsp"
            it.start()
        }

        return true
    }

    private fun startCompressedFileDspPlayback(filePath: String): Boolean {
        val processor = ensureDspProcessorReady()
        if (processor == null) {
            lastPlaybackError = "DSP processor unavailable"
            return false
        }

        val extractor = MediaExtractor()
        val selectedTrack = try {
            extractor.setDataSource(filePath)
            findFirstAudioTrack(extractor)
        } catch (e: Throwable) {
            Log.e(TAG, "Failed opening media file: $filePath", e)
            null
        }

        if (selectedTrack == null) {
            try {
                extractor.release()
            } catch (_: Throwable) {
            }
            Log.e(TAG, "No audio track found in file: $filePath")
            lastPlaybackError = "No audio track found in file"
            return false
        }

        val (trackIndex, format) = selectedTrack
        val mime = format.getString(MediaFormat.KEY_MIME)
        if (mime.isNullOrBlank()) {
            extractor.release()
            Log.e(TAG, "Invalid media MIME type")
            lastPlaybackError = "Invalid media MIME type"
            return false
        }

        val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        if (channels <= 0) {
            extractor.release()
            Log.e(TAG, "Invalid channel count in media file")
            lastPlaybackError = "Invalid channel count in media"
            return false
        }

        val codec = try {
            MediaCodec.createDecoderByType(mime)
        } catch (e: Throwable) {
            extractor.release()
            Log.e(TAG, "Decoder creation failed for MIME: $mime", e)
            lastPlaybackError = "Decoder creation failed for $mime"
            return false
        }

        val frameSize = 512
        val minBuffer = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuffer == AudioTrack.ERROR || minBuffer == AudioTrack.ERROR_BAD_VALUE) {
            extractor.release()
            codec.release()
            Log.e(TAG, "Invalid min buffer size for compressed playback")
            lastPlaybackError = "Invalid AudioTrack min buffer size for compressed"
            return false
        }

        val desiredBuffer = maxOf(minBuffer, frameSize * 8)
        val track = AudioTrack(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build(),
            AudioFormat.Builder()
                .setSampleRate(sampleRate)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .build(),
            desiredBuffer,
            AudioTrack.MODE_STREAM,
            AudioManager.AUDIO_SESSION_ID_GENERATE,
        )

        if (track.state != AudioTrack.STATE_INITIALIZED) {
            extractor.release()
            codec.release()
            track.release()
            Log.e(TAG, "AudioTrack failed to initialize for compressed playback")
            lastPlaybackError = "AudioTrack initialization failed for compressed"
            return false
        }

        fileAudioTrack = track
        filePlaybackRunning = true
        lastPlaybackError = "none"

        filePlaybackThread = Thread {
            val outputShort = ShortArray(frameSize)
            val pendingSamples = ArrayDeque<Float>(frameSize * 4)
            val bufferInfo = MediaCodec.BufferInfo()

            var inputDone = false
            var outputDone = false

            try {
                extractor.selectTrack(trackIndex)
                codec.configure(format, null, null, 0)
                codec.start()
                track.play()

                while (filePlaybackRunning && !outputDone) {
                    if (!inputDone) {
                        val inputIndex = codec.dequeueInputBuffer(10_000)
                        if (inputIndex >= 0) {
                            val inputBuffer = codec.getInputBuffer(inputIndex)
                            if (inputBuffer != null) {
                                val sampleSize = extractor.readSampleData(inputBuffer, 0)
                                if (sampleSize < 0) {
                                    codec.queueInputBuffer(
                                        inputIndex,
                                        0,
                                        0,
                                        0,
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                    )
                                    inputDone = true
                                } else {
                                    val sampleTimeUs = extractor.sampleTime
                                    codec.queueInputBuffer(
                                        inputIndex,
                                        0,
                                        sampleSize,
                                        sampleTimeUs,
                                        0,
                                    )
                                    extractor.advance()
                                }
                            }
                        }
                    }

                    val outputIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000)
                    when {
                        outputIndex >= 0 -> {
                            val outputBuffer = codec.getOutputBuffer(outputIndex)
                            if (outputBuffer != null && bufferInfo.size > 0) {
                                outputBuffer.position(bufferInfo.offset)
                                outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                                extractMonoSamplesFromPcm16(
                                    buffer = outputBuffer,
                                    channels = channels,
                                    target = pendingSamples,
                                )
                            }

                            codec.releaseOutputBuffer(outputIndex, false)
                            if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                                outputDone = true
                            }

                            while (pendingSamples.size >= frameSize) {
                                val frame = FloatArray(frameSize)
                                for (i in 0 until frameSize) {
                                    frame[i] = pendingSamples.removeFirst()
                                }
                                val written = processFrameAndWrite(
                                    processor = processor,
                                    input = frame,
                                    outputShort = outputShort,
                                    track = track,
                                    label = "Compressed",
                                )
                                if (written < 0) {
                                    lastPlaybackError = "Compressed playback write failed ($written)"
                                    outputDone = true
                                    break
                                }
                            }
                        }
                        outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            val outFormat = codec.outputFormat
                            Log.i(TAG, "Decoder output format changed: $outFormat")
                        }
                    }
                }

                if (filePlaybackRunning && pendingSamples.isNotEmpty()) {
                    val tailSize = pendingSamples.size
                    val tail = FloatArray(tailSize)
                    for (i in 0 until tailSize) {
                        tail[i] = pendingSamples.removeFirst()
                    }
                    processFrameAndWrite(
                        processor = processor,
                        input = tail,
                        outputShort = outputShort,
                        track = track,
                        label = "CompressedTail",
                    )
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Compressed file DSP playback crashed", e)
                lastPlaybackError = "Compressed DSP thread crashed: ${e.message}"
            } finally {
                filePlaybackRunning = false
                try {
                    codec.stop()
                } catch (_: Throwable) {
                }
                try {
                    codec.release()
                } catch (_: Throwable) {
                }
                try {
                    extractor.release()
                } catch (_: Throwable) {
                }
                try {
                    track.pause()
                    track.flush()
                    track.stop()
                } catch (_: Throwable) {
                }
            }
        }.also {
            it.name = "NeuroAmpCompressedFileDsp"
            it.start()
        }

        return true
    }

    private fun stopFileDspPlayback(): Boolean {
        if (!filePlaybackRunning && filePlaybackThread == null && fileAudioTrack == null) {
            return true
        }

        filePlaybackRunning = false

        try {
            filePlaybackThread?.join(500)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }

        filePlaybackThread = null

        fileAudioTrack?.let { track ->
            try {
                track.pause()
                track.flush()
                track.stop()
            } catch (_: Throwable) {
            } finally {
                try {
                    track.release()
                } catch (_: Throwable) {
                }
            }
        }
        fileAudioTrack = null

        return true
    }

    private fun parseWavInfo(filePath: String): WavInfo? {
        RandomAccessFile(filePath, "r").use { raf ->
            if (raf.length() < 44) {
                return null
            }

            val riff = ByteArray(4)
            raf.readFully(riff)
            if (String(riff) != "RIFF") {
                return null
            }

            raf.skipBytes(4)

            val wave = ByteArray(4)
            raf.readFully(wave)
            if (String(wave) != "WAVE") {
                return null
            }

            var channels = 0
            var sampleRate = 0
            var bitsPerSample = 0
            var dataOffset = -1L
            var dataSize = 0L

            while (raf.filePointer + 8 <= raf.length()) {
                val chunkId = ByteArray(4)
                raf.readFully(chunkId)
                val chunkName = String(chunkId)
                val chunkSize = readUInt32LE(raf)
                val chunkDataStart = raf.filePointer

                when (chunkName) {
                    "fmt " -> {
                        val audioFormat = readUInt16LE(raf)
                        channels = readUInt16LE(raf)
                        sampleRate = readUInt32LE(raf)
                        raf.skipBytes(6)
                        bitsPerSample = readUInt16LE(raf)
                        if (audioFormat != 1) {
                            return null
                        }
                    }
                    "data" -> {
                        dataOffset = raf.filePointer
                        dataSize = chunkSize.toLong()
                    }
                }

                val nextChunk = chunkDataStart + chunkSize.toLong()
                raf.seek(nextChunk)
                if (chunkSize % 2 != 0 && raf.filePointer < raf.length()) {
                    raf.skipBytes(1)
                }

                if (channels > 0 && sampleRate > 0 && bitsPerSample > 0 && dataOffset >= 0) {
                    break
                }
            }

            if (channels <= 0 || sampleRate <= 0 || bitsPerSample <= 0 || dataOffset < 0) {
                return null
            }

            return WavInfo(
                channels = channels,
                sampleRate = sampleRate,
                bitsPerSample = bitsPerSample,
                dataOffset = dataOffset,
                dataSize = dataSize,
            )
        }
    }

    private fun readUInt16LE(raf: RandomAccessFile): Int {
        val b0 = raf.readUnsignedByte()
        val b1 = raf.readUnsignedByte()
        return b0 or (b1 shl 8)
    }

    private fun readUInt32LE(raf: RandomAccessFile): Int {
        val b0 = raf.readUnsignedByte()
        val b1 = raf.readUnsignedByte()
        val b2 = raf.readUnsignedByte()
        val b3 = raf.readUnsignedByte()
        return b0 or (b1 shl 8) or (b2 shl 16) or (b3 shl 24)
    }

    private fun findFirstAudioTrack(extractor: MediaExtractor): Pair<Int, MediaFormat>? {
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime != null && mime.startsWith("audio/")) {
                return i to format
            }
        }
        return null
    }

    private fun extractMonoSamplesFromPcm16(
        buffer: ByteBuffer,
        channels: Int,
        target: ArrayDeque<Float>,
    ) {
        val order = buffer.order()
        buffer.order(ByteOrder.LITTLE_ENDIAN)
        try {
            val shortBuffer = buffer.asShortBuffer()
            val totalShorts = shortBuffer.remaining()
            if (channels == 1) {
                while (shortBuffer.hasRemaining()) {
                    target.addLast((shortBuffer.get() / 32768.0f).coerceIn(-1.0f, 1.0f))
                }
            } else {
                val frameCount = totalShorts / channels
                for (frameIndex in 0 until frameCount) {
                    var sum = 0f
                    for (c in 0 until channels) {
                        sum += (shortBuffer.get() / 32768.0f)
                    }
                    target.addLast((sum / channels.toFloat()).coerceIn(-1.0f, 1.0f))
                }
            }
        } finally {
            buffer.order(order)
        }
    }

    private fun processFrameAndWrite(
        processor: DspProcessor,
        input: FloatArray,
        outputShort: ShortArray,
        track: AudioTrack,
        label: String,
    ): Int {
        var inSq = 0.0f
        for (sample in input) {
            inSq += sample * sample
        }
        lastInputRms = kotlin.math.sqrt(inSq / input.size.coerceAtLeast(1).toFloat())

        val processed = try {
            processor.processFrame(input, currentDspConfig)
        } catch (e: Throwable) {
            Log.e(TAG, "$label DSP processing failed", e)
            input
        }

        var outSq = 0.0f
        for (i in processed.indices) {
            val amplified = (processed[i] * outputGainLinear).coerceIn(-1.0f, 1.0f)
            outSq += amplified * amplified
            val scaled = (amplified * Short.MAX_VALUE).toInt()
            outputShort[i] = scaled.toShort()
        }

        lastOutputRms = kotlin.math.sqrt(outSq / processed.size.coerceAtLeast(1).toFloat())

        return track.write(outputShort, 0, processed.size)
    }

    private fun pcm16ToFloat(lo: Byte, hi: Byte): Float {
        val sample = ((hi.toInt() shl 8) or (lo.toInt() and 0xFF)).toShort()
        return (sample / 32768.0f).coerceIn(-1.0f, 1.0f)
    }

    private fun ensureDspProcessorReady(): DspProcessor? {
        val current = dspProcessor
        if (current != null) {
            return current
        }

        return try {
            val processor = DspProcessor()
            val ok = processor.initialize(48000)
            if (!ok) {
                Log.e(TAG, "ensureDspProcessorReady: initialize failed")
                null
            } else {
                dspProcessor = processor
                processor
            }
        } catch (e: Throwable) {
            Log.e(TAG, "ensureDspProcessorReady failed", e)
            null
        }
    }

    private fun dbToLinear(gainDb: Float): Float {
        return Math.pow(10.0, (gainDb / 20.0).toDouble()).toFloat()
    }

    init {
        try {
            System.loadLibrary("neuroamp_dsp")
        } catch (_: UnsatisfiedLinkError) {
            // If native library is unavailable in debug env, channel still works for sensors.
        }
    }
}
