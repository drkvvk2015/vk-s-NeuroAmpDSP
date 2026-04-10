package com.neuroamp.app.audio

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.audiofx.AudioEffect

class EnhancedAudioSessionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val sessionId = intent.getIntExtra(AudioEffect.EXTRA_AUDIO_SESSION, AudioEffect.ERROR_BAD_VALUE)
        if (sessionId == AudioEffect.ERROR_BAD_VALUE) {
            return
        }

        val packageName = intent.getStringExtra(AudioEffect.EXTRA_PACKAGE_NAME).orEmpty()
        when (intent.action) {
            AudioEffect.ACTION_OPEN_AUDIO_EFFECT_CONTROL_SESSION -> {
                ExternalAudioEffectController.openSession(sessionId, packageName.ifEmpty { "unknown" })
            }
            AudioEffect.ACTION_CLOSE_AUDIO_EFFECT_CONTROL_SESSION -> {
                ExternalAudioEffectController.closeSession(sessionId)
            }
        }
    }
}