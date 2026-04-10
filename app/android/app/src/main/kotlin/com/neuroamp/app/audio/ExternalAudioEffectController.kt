package com.neuroamp.app.audio

import android.content.ComponentName
import android.content.Context
import android.media.audiofx.AudioEffect
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.Virtualizer
import android.provider.Settings
import com.neuroamp.app.dsp.DspConfig
import kotlin.math.abs

object ExternalAudioEffectController {
    private var mode: DspMode = DspMode.STANDARD
    private var currentConfig: DspConfig = DspConfig()
    private var outputGainDb: Float = 0.0f
    private var activeMediaPackage: String? = null
    private var lastExternalSessionError: String = "idle"

    private data class ManagedEffects(
        val packageName: String,
        val equalizer: Equalizer?,
        val bassBoostEffect: BassBoost?,
        val virtualizerEffect: Virtualizer?,
        val loudnessEnhancer: LoudnessEnhancer?,
    )

    private val activeEffects = linkedMapOf<Int, ManagedEffects>()

    fun setMode(mode: DspMode) {
        this.mode = mode
        if (!mode.usesExternalEffects()) {
            releaseAllSessions()
            lastExternalSessionError = "idle"
            return
        }

        activeEffects.values.forEach { applyCurrentProfile(it) }
    }

    fun getMode(): DspMode = mode

    fun updateProfile(config: DspConfig, outputGainDb: Float) {
        currentConfig = config
        this.outputGainDb = outputGainDb
        if (!mode.usesExternalEffects()) {
            return
        }
        activeEffects.values.forEach { applyCurrentProfile(it) }
    }

    fun noteMediaApp(packageName: String?) {
        if (!packageName.isNullOrBlank()) {
            activeMediaPackage = packageName
        }
    }

    fun openSession(sessionId: Int, packageName: String) {
        if (!mode.usesExternalEffects()) {
            lastExternalSessionError = "External audio effects are disabled in ${mode.wireName} mode"
            return
        }
        if (activeEffects.containsKey(sessionId)) {
            noteMediaApp(packageName)
            return
        }

        try {
            val effects = ManagedEffects(
                packageName = packageName,
                equalizer = runCatching { Equalizer(0, sessionId).apply { enabled = true } }.getOrNull(),
                bassBoostEffect = runCatching { BassBoost(0, sessionId).apply { enabled = true } }.getOrNull(),
                virtualizerEffect = runCatching { Virtualizer(0, sessionId).apply { enabled = true } }.getOrNull(),
                loudnessEnhancer = runCatching { LoudnessEnhancer(sessionId).apply { enabled = true } }.getOrNull(),
            )
            activeEffects[sessionId] = effects
            noteMediaApp(packageName)
            applyCurrentProfile(effects)
            lastExternalSessionError = "none"
        } catch (t: Throwable) {
            lastExternalSessionError = "Failed to attach external session $sessionId: ${t.message ?: "unknown"}"
        }
    }

    fun closeSession(sessionId: Int) {
        activeEffects.remove(sessionId)?.let { releaseEffects(it) }
        if (activeEffects.isEmpty()) {
            activeMediaPackage = null
        }
    }

    fun releaseAllSessions() {
        activeEffects.values.forEach(::releaseEffects)
        activeEffects.clear()
        activeMediaPackage = null
    }

    fun getStatus(
        context: Context,
        shizukuAvailable: Boolean,
        shizukuPermissionGranted: Boolean,
        rootAvailable: Boolean,
    ): Map<String, Any> {
        val descriptors = AudioEffect.queryEffects()?.toList().orEmpty()
        val enhancedSupported = descriptors.any { descriptor ->
            descriptor.type == AudioEffect.EFFECT_TYPE_EQUALIZER ||
                descriptor.type == AudioEffect.EFFECT_TYPE_BASS_BOOST ||
                descriptor.type == AudioEffect.EFFECT_TYPE_VIRTUALIZER ||
                descriptor.type == AudioEffect.EFFECT_TYPE_LOUDNESS_ENHANCER
        }

        return mapOf(
            "selectedMode" to mode.wireName,
            "enhancedModeSupported" to enhancedSupported,
            "notificationAccessEnabled" to isNotificationAccessEnabled(context),
            "externalSessionCount" to activeEffects.size,
            "activeMediaPackage" to (activeMediaPackage ?: ""),
            "attachedPackages" to activeEffects.values.map { it.packageName }.distinct(),
            "shizukuAvailable" to shizukuAvailable,
            "shizukuPermissionGranted" to shizukuPermissionGranted,
            "rootAvailable" to rootAvailable,
            "lastExternalSessionError" to lastExternalSessionError,
        )
    }

    fun isNotificationAccessEnabled(context: Context): Boolean {
        val enabled = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false

        val packageName = context.packageName
        return enabled.split(':')
            .mapNotNull { runCatching { ComponentName.unflattenFromString(it) }.getOrNull() }
            .any { it.packageName == packageName }
    }

    private fun applyCurrentProfile(effects: ManagedEffects) {
        effects.equalizer?.let { equalizer ->
            val range = equalizer.bandLevelRange
            for (bandIndex in 0 until equalizer.numberOfBands) {
                val centerHz = equalizer.getCenterFreq(bandIndex.toShort()) / 1000.0
                val nearest = currentConfig.eqBands.minByOrNull { abs(it.frequencyHz - centerHz) }
                val targetLevel = (((nearest?.gainDb ?: 0.0f) * 100.0f).toInt())
                    .coerceIn(range[0].toInt(), range[1].toInt())
                equalizer.setBandLevel(bandIndex.toShort(), targetLevel.toShort())
            }
        }

        effects.bassBoostEffect?.setStrength((currentConfig.bassBoostDb.coerceIn(0.0f, 6.0f) / 6.0f * 1000).toInt().toShort())
        effects.virtualizerEffect?.setStrength((currentConfig.spatialWidth.coerceIn(0.0f, 1.0f) * 1000).toInt().toShort())
        effects.loudnessEnhancer?.setTargetGain((outputGainDb * 100.0f).toInt())
    }

    private fun releaseEffects(effects: ManagedEffects) {
        runCatching { effects.equalizer?.release() }
        runCatching { effects.bassBoostEffect?.release() }
        runCatching { effects.virtualizerEffect?.release() }
        runCatching { effects.loudnessEnhancer?.release() }
    }
}

private fun DspMode.usesExternalEffects(): Boolean {
    return this == DspMode.ENHANCED || this == DspMode.PRO || this == DspMode.ROOT
}