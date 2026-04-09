package com.neuroamp.app

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private var rotationSensor: Sensor? = null
    private var yawDegrees: Double = 0.0

    companion object {
        private const val CHANNEL = "com.neuroamp/dsp"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getHeadTrackingYaw" -> result.success(yawDegrees)
                    "getDspEngineVersion" -> result.success(getDspEngineVersion())
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

        // orientation[0] is azimuth in radians. Convert for Dart side consumption.
        yawDegrees = Math.toDegrees(orientation[0].toDouble())
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // No-op.
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
