package com.example.snooze_fest

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import android.os.Vibrator
import android.os.VibrationEffect
import android.os.VibratorManager
import android.net.Uri
import java.io.File
import android.media.AudioManager

class AlarmForegroundService : Service() {
    private var mediaPlayer: MediaPlayer? = null
    private val CHANNEL_ID = "alarm_service_channel"
    private val NOTIFICATION_ID = 1
    private var vibrator: Vibrator? = null
    private var vibrationActive = false
    private var currentAudioPath: String? = null
    private var currentAlarmId: Int? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, createNotification()) // Always call first!

        // Set alarm stream volume to max
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val maxVolume = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVolume, 0)

        val vibrate = intent?.getBooleanExtra("vibrate", false) ?: false
        val audioPath = intent?.getStringExtra("audioPath") ?: ""
        val alarmId = intent?.getIntExtra("alarmId", -1) ?: -1

        Log.d("AlarmForegroundService", "onStartCommand: alarmId=$alarmId, audioPath=$audioPath, currentAlarmId=$currentAlarmId, currentAudioPath=$currentAudioPath")

        // Defensive: If intent is invalid, stop service and return
        if (alarmId == -1 || audioPath.isEmpty()) {
            Log.e("AlarmForegroundService", "Invalid intent received, stopping service.")
            stopSelf()
            return START_NOT_STICKY
        }

        // Only play if not already playing this alarm/audio
        if (currentAlarmId != alarmId || currentAudioPath != audioPath) {
            stopAlarmSound()
            playAlarmSound(audioPath)
            currentAudioPath = audioPath
            currentAlarmId = alarmId
        }
        if (vibrate && !vibrationActive) startVibration()
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("AlarmForegroundService", "Service destroyed")
        stopAlarmSound()
        stopVibration()
        currentAudioPath = null
        currentAlarmId = null
    }

    private fun playAlarmSound(audioPath: String) {
        if (mediaPlayer == null) {
            try {
                if (audioPath.isNotEmpty() && audioPath != "assets/alarm.mp3") {
                    if (audioPath.startsWith("content://")) {
                        // Play from content URI
                        val uri = Uri.parse(audioPath)
                        mediaPlayer = MediaPlayer()
                        mediaPlayer?.setDataSource(applicationContext, uri)
                        mediaPlayer?.isLooping = true
                        mediaPlayer?.setVolume(1.0f, 1.0f)
                        mediaPlayer?.prepare()
                        mediaPlayer?.start()
                        return
                    } else {
                        // Play user file from file system
                        val file = File(audioPath)
                        if (file.exists()) {
                            mediaPlayer = MediaPlayer()
                            mediaPlayer?.setDataSource(file.absolutePath)
                            mediaPlayer?.isLooping = true
                            mediaPlayer?.setVolume(1.0f, 1.0f)
                            mediaPlayer?.prepare()
                            mediaPlayer?.start()
                            return
                        }
                    }
                }
                // Fallback to default alarm.mp3 in res/raw
                val afd = resources.openRawResourceFd(R.raw.alarm)
                mediaPlayer = MediaPlayer()
                mediaPlayer?.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                mediaPlayer?.isLooping = true
                mediaPlayer?.setVolume(1.0f, 1.0f)
                mediaPlayer?.prepare()
                mediaPlayer?.start()
            } catch (e: Exception) {
                Log.e("AlarmForegroundService", "Error playing alarm sound: $e")
            }
        }
    }

    private fun stopAlarmSound() {
        mediaPlayer?.stop()
        mediaPlayer?.release()
        mediaPlayer = null
    }

    private fun startVibration() {
        if (vibrationActive) return
        vibrationActive = true
        vibrator = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            vm.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        val pattern = longArrayOf(0, 500, 1000) // wait, vibrate, sleep
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            vibrator?.vibrate(VibrationEffect.createWaveform(pattern, 0))
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
    }

    private fun stopVibration() {
        if (!vibrationActive) return
        vibrationActive = false
        vibrator?.cancel()
    }

    private fun createNotification(): Notification {
        createNotificationChannel()
        val notificationIntent = Intent(this, FlutterActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Alarm Ringing")
            .setContentText("Tap to return to the alarm app.")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarm Service Channel",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description = "Channel for alarm foreground service"
            channel.setSound(null, null)
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
} 