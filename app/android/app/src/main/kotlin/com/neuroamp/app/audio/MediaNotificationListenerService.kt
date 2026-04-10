package com.neuroamp.app.audio

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class MediaNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.notification.category == android.app.Notification.CATEGORY_TRANSPORT) {
            ExternalAudioEffectController.noteMediaApp(sbn.packageName)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        if (sbn.notification.category == android.app.Notification.CATEGORY_TRANSPORT) {
            ExternalAudioEffectController.noteMediaApp(null)
        }
    }
}