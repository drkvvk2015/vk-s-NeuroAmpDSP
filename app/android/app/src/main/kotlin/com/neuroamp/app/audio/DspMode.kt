package com.neuroamp.app.audio

enum class DspMode(val wireName: String) {
    STANDARD("standard"),
    ENHANCED("enhanced"),
    PRO("pro"),
    ROOT("root");

    companion object {
        fun fromWireName(raw: String?): DspMode {
            return entries.firstOrNull { it.wireName == raw } ?: STANDARD
        }
    }
}