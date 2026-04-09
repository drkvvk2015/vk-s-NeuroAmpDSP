package com.neuroamp.app.dsp

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

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
        // Simplified serialization for demo; production would use protobuf.
        val buffer = mutableListOf<Byte>()
        buffer.add(1) // version
        buffer.add(if (config.convolverEnabled) 1 else 0)
        addFloatBytes(buffer, config.bassBoostDb)
        addFloatBytes(buffer, config.spatialWidth)
        addFloatBytes(buffer, config.peakLimiterDb)
        buffer.add(config.eqBands.size.toByte())
        config.eqBands.forEach { band ->
            addDoubleBytes(buffer, band.frequencyHz)
            addFloatBytes(buffer, band.gainDb)
            addFloatBytes(buffer, band.q)
        }
        return buffer.toByteArray()
    }

    private fun addFloatBytes(buffer: MutableList<Byte>, value: Float) {
        val bits = value.toBits()
        buffer.add((bits shr 24).toByte())
        buffer.add((bits shr 16).toByte())
        buffer.add((bits shr 8).toByte())
        buffer.add(bits.toByte())
    }

    private fun addDoubleBytes(buffer: MutableList<Byte>, value: Double) {
        val bits = value.toBits()
        repeat(8) { i -> buffer.add((bits shr (56 - i * 8)).toByte()) }
    }
}
