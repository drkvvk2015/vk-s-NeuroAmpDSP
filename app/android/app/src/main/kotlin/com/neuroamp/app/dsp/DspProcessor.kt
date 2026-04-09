package com.neuroamp.app.dsp

import java.nio.ByteBuffer
import java.nio.ByteOrder

data class DspConfig(
    val eqBands: List<EqBand> = emptyList(),
    val bassBoostDb: Float = 0f,
    val spatialWidth: Float = 0.25f,
    val peakLimiterDb: Float = -1f,
    val convolverEnabled: Boolean = false
)

data class EqBand(
    val frequencyHz: Double,
    val gainDb: Float,
    val q: Float
)

class DspProcessor {
    companion object {
        private const val MAX_EQ_BANDS = 5

        external fun processAudioFrame(
            inputSamples: FloatArray,
            outputSamples: FloatArray,
            config: ByteArray
        ): Boolean

        external fun initializeDspEngine(sampleRate: Int): Boolean

        external fun releaseDspEngine(): Boolean
    }

    init {
        try {
            System.loadLibrary("neuroamp_dsp")
        } catch (e: UnsatisfiedLinkError) {
            throw RuntimeException("Failed to load native DSP library", e)
        }
    }

    fun initialize(sampleRate: Int): Boolean = initializeDspEngine(sampleRate)

    fun release(): Boolean = releaseDspEngine()

    fun processFrame(inputSamples: FloatArray, config: DspConfig): FloatArray {
        val outputSamples = FloatArray(inputSamples.size)
        val configBytes = serializeConfig(config)
        val success = processAudioFrame(inputSamples, outputSamples, configBytes)
        return if (success) outputSamples else inputSamples
    }

    private fun serializeConfig(config: DspConfig): ByteArray {
        val eqBands = config.eqBands.take(MAX_EQ_BANDS)
        val headerBytes = 1 + 1 + 4 + 4 + 4 + 1
        val bytesPerBand = 8 + 4 + 4
        val byteBuffer = ByteBuffer
            .allocate(headerBytes + (eqBands.size * bytesPerBand))
            .order(ByteOrder.LITTLE_ENDIAN)

        byteBuffer.put(1) // version
        byteBuffer.put(if (config.convolverEnabled) 1 else 0)
        byteBuffer.putFloat(config.bassBoostDb)
        byteBuffer.putFloat(config.spatialWidth)
        byteBuffer.putFloat(config.peakLimiterDb)
        byteBuffer.put(eqBands.size.toByte())
        eqBands.forEach { band ->
            byteBuffer.putDouble(band.frequencyHz)
            byteBuffer.putFloat(band.gainDb)
            byteBuffer.putFloat(band.q)
        }
        return byteBuffer.array()
    }
}
