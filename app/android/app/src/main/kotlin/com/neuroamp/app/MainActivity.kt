package com.neuroamp.app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import com.neuroamp.app.dsp.DspProcessor
import com.neuroamp.app.dsp.DspConfig
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var rotationSensor: Sensor? = null
    private var yawDegrees: Double = 0.0
    private var dspProcessor: DspProcessor? = null
    private var currentDspConfig: DspConfig = DspConfig()

    companion object {
        private const val CHANNEL = "com.neuroamp/dsp"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

        // Initialize DSP processor
        try {
            dspProcessor = DspProcessor()
            dspProcessor?.initialize(48000)
        } catch (e: Exception) {
            // DSP unavailable; continue with sensor-only mode
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
                            val processedSamples = processor.processFrame(
                                floatSamples,
                                currentDspConfig
                            )
                            result.success(processedSamples.map { it.toDouble() })
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
                        val success = dspProcessor?.initialize(sampleRate) ?: false
                        result.success(success)
                    }
                    "releaseDsp" -> {
                        val success = dspProcessor?.release() ?: false
                        result.success(success)
                    }
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

    init {
        try {
            System.loadLibrary("neuroamp_dsp")
        } catch (_: UnsatisfiedLinkError) {
            // If native library is unavailable in debug env, channel still works for sensors.
        }
    }
}
