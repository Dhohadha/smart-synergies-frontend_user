package com.smart_synergies_user.app

import android.app.Application
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences

class SmartSynergiesApplication : Application() {
    private lateinit var prefs: SharedPreferences
    private val listener = SharedPreferences.OnSharedPreferenceChangeListener { sharedPreferences, key ->
        if (key == "flutter.alarm_playing") {
            val isPlaying = sharedPreferences.getBoolean(key, false)
            val soundEnabled = sharedPreferences.getBoolean("flutter.alert_sound_enabled", true)
            
            if (isPlaying && soundEnabled) {
                val serviceIntent = Intent(this, AlarmSoundService::class.java)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
            } else {
                val serviceIntent = Intent(this, AlarmSoundService::class.java)
                serviceIntent.action = AlarmSoundService.ACTION_STOP
                startService(serviceIntent)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        // SharedPreferences used by flutter's shared_preferences plugin
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.registerOnSharedPreferenceChangeListener(listener)
    }
}
