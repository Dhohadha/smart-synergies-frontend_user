package com.smart_synergies_user.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log

/**
 * Native foreground service that handles alarm audio when the Flutter app is in the background.
 *
 * Why a native service?
 * - Flutter background Dart isolates cannot run long-lived timers or audio players
 * - Android audio APIs (MediaPlayer) outlive Dart isolate lifecycles
 * - This service shows its own foreground notification with a STOP button that is
 *   ALWAYS visible in the notification shade (no need to expand)
 *
 * Lifecycle:
 *   1. Started by SmartSynergiesApplication when alarm_playing=true is written to SharedPreferences
 *   2. Plays alarm.mp3 in a loop for 90 sec, silences for 1 min, repeats × 4
 *   3. Stopped by STOP button press, Flutter stopAlarmNow(), or after 4 cycles
 */
class AlarmSoundService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var cycleCount = 0
    private var isRunning = false

    companion object {
        const val ACTION_STOP = "com.smart_synergies_user.app.STOP_ALARM_SERVICE"
        const val NOTIF_ID = 889
        const val SERVICE_CHANNEL_ID = "alarm_sound_service_channel"
        private const val TAG = "AlarmSoundService"
        private const val MAX_CYCLES = 4
        private const val PLAY_DURATION_MS = 90_000L
        private const val SILENCE_DURATION_MS = 60_000L
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createServiceNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            Log.d(TAG, "STOP action received — stopping service")
            handleStop()
            return START_NOT_STICKY
        }

        if (!isRunning) {
            Log.d(TAG, "Starting alarm foreground service")
            isRunning = true
            cycleCount = 0
            startForeground(NOTIF_ID, buildForegroundNotification())
            runCycle()
        } else {
            Log.d(TAG, "Service already running — ignoring duplicate start")
        }

        return START_STICKY
    }

    // ─── Alarm cycle ──────────────────────────────────────────────────────────

    private fun runCycle() {
        if (!isRunning) return

        if (cycleCount >= MAX_CYCLES) {
            Log.d(TAG, "Max cycles ($MAX_CYCLES) reached — stopping")
            handleStop()
            return
        }

        cycleCount++
        Log.d(TAG, "Starting cycle $cycleCount / $MAX_CYCLES")

        playAudio()

        // After 90 s: silence the audio
        handler.postDelayed({
            if (isRunning) {
                Log.d(TAG, "90 s elapsed — silencing cycle $cycleCount")
                mediaPlayer?.pause()
                // After 1 min silence: next cycle
                handler.postDelayed({
                    if (isRunning) {
                        runCycle()
                    }
                }, SILENCE_DURATION_MS)
            }
        }, PLAY_DURATION_MS)
    }

    private fun playAudio() {
        try {
            mediaPlayer?.stop()
            mediaPlayer?.release()
            
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
            )
            
            val fd = resources.openRawResourceFd(R.raw.alarm)
            mp.setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
            fd.close()
            
            mp.isLooping = true
            mp.prepare()
            mp.start()
            
            mediaPlayer = mp
            Log.d(TAG, "Audio started for cycle $cycleCount on ALARM stream")
        } catch (e: Exception) {
            Log.e(TAG, "Error playing audio: ${e.message}")
        }
    }

    // ─── Stop ─────────────────────────────────────────────────────────────────

    private fun handleStop() {
        isRunning = false
        handler.removeCallbacksAndMessages(null)

        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null

        // Cancel the flutter_local_notifications alarm notification (ID 888)
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(888)

        // Clear alarm flags in SharedPreferences so Flutter UI reflects the stop
        val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        prefs.edit()
            .putBoolean("flutter.alarm_playing", false)
            .putBoolean("flutter.isAlarmStopped", true)
            .apply()

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        Log.d(TAG, "Service stopped cleanly")
    }

    override fun onDestroy() {
        handleStop()
        super.onDestroy()
    }

    // ─── Notification ─────────────────────────────────────────────────────────

    /**
     * Builds the foreground service notification.
     *
     * KEY DIFFERENCE from flutter_local_notifications heads-up:
     * This notification always shows action buttons (STOP) directly in the
     * notification shade — no dragging or expanding required.
     */
    private fun buildForegroundNotification(): Notification {
        // STOP action — sends ACTION_STOP to this service
        val stopIntent = PendingIntent.getService(
            this, 100,
            Intent(this, AlarmSoundService::class.java).apply { action = ACTION_STOP },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Tap notification body → open alarm screen natively
        val openIntent = PendingIntent.getActivity(
            this, 101,
            Intent(this, LockScreenAlarmActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, SERVICE_CHANNEL_ID)
                .setContentTitle("⚠️ AERATOR ALERT!")
                .setContentText("An aerator requires immediate attention. Tap to view.")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(openIntent)
                .setFullScreenIntent(openIntent, true)
                .setOngoing(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setCategory(Notification.CATEGORY_ALARM)
                .addAction(
                    Notification.Action.Builder(
                        null, "🔕 STOP ALARM", stopIntent
                    ).build()
                )
                .build()
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(this)
                .setContentTitle("⚠️ AERATOR ALERT!")
                .setContentText("An aerator requires immediate attention.")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentIntent(openIntent)
                .setFullScreenIntent(openIntent, true)
                .setOngoing(true)
                .setVisibility(Notification.VISIBILITY_PUBLIC)
                .setCategory(Notification.CATEGORY_ALARM)
                .addAction(android.R.drawable.ic_media_pause, "🔕 STOP ALARM", stopIntent)
                .build()
        }
    }

    private fun createServiceNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                SERVICE_CHANNEL_ID,
                "Alarm Service",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setSound(null, null)  // Service notif uses no sound (audio via MediaPlayer)
                enableVibration(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }
}
