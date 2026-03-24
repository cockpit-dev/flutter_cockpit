package dev.cockpit.flutter_cockpit

import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.File

internal class FlutterCockpitRecordingService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())

    private var mediaProjection: MediaProjection? = null
    private var mediaRecorder: MediaRecorder? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var projectionCallback: MediaProjection.Callback? = null
    private var outputPath: String? = null
    private var isRecording = false
    private var startedAtElapsedMs: Long = 0L

    override fun onCreate() {
        super.onCreate()
        activeService = this
        createNotificationChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_START) {
            stopSelf()
            return START_NOT_STICKY
        }

        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
        val projectionData = intentExtraIntent(intent, EXTRA_PROJECTION_DATA)
        val relativePath = intent.getStringExtra(EXTRA_RELATIVE_PATH)

        if (projectionData == null || relativePath.isNullOrBlank()) {
            resolvePendingStart(
                mapOf<String, Any>(
                    "state" to "failed",
                    "failureReason" to "invalidStartArguments",
                ),
            )
            stopSelf()
            return START_NOT_STICKY
        }

        startForegroundCompat(buildNotification())
        startRecording(resultCode, projectionData, relativePath)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        activeService = null
        cleanupProjection()
        super.onDestroy()
    }

    fun stopRecording(onComplete: (Map<String, Any?>) -> Unit) {
        if (!isRecording) {
            onComplete(
                mapOf<String, Any>(
                    "state" to "failed",
                    "failureReason" to "recordingNotActive",
                ),
            )
            return
        }

        stopRecordingInternal(
            failureReason = null,
            onComplete = onComplete,
        )
    }

    private fun startRecording(
        resultCode: Int,
        projectionData: Intent,
        relativePath: String,
    ) {
        val outputFile = File(cacheDir, relativePath)
        outputFile.parentFile?.mkdirs()
        if (outputFile.exists()) {
            outputFile.delete()
        }

        val metrics = resources.displayMetrics
        val width = metrics.widthPixels.coerceAtLeast(1)
        val height = metrics.heightPixels.coerceAtLeast(1)
        val density = metrics.densityDpi.coerceAtLeast(1)

        try {
            val projectionManager =
                getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val projection = projectionManager.getMediaProjection(resultCode, projectionData)
            if (projection == null) {
                resolvePendingStart(
                    mapOf<String, Any>(
                        "state" to "failed",
                        "failureReason" to "projectionUnavailable",
                    ),
                )
                stopSelf()
                return
            }

            val recorder = MediaRecorder()
            recorder.setVideoSource(MediaRecorder.VideoSource.SURFACE)
            recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            recorder.setOutputFile(outputFile.absolutePath)
            recorder.setVideoEncoder(MediaRecorder.VideoEncoder.H264)
            recorder.setVideoFrameRate(30)
            recorder.setVideoEncodingBitRate((width * height * 6).coerceAtLeast(4_000_000))
            recorder.setVideoSize(width, height)
            recorder.prepare()

            val callback =
                object : MediaProjection.Callback() {
                    override fun onStop() {
                        if (isRecording) {
                            stopRecordingInternal(
                                failureReason = "projectionStopped",
                                onComplete = null,
                            )
                        }
                    }
                }

            projection.registerCallback(callback, mainHandler)
            val display =
                projection.createVirtualDisplay(
                    "flutter_cockpit_recording",
                    width,
                    height,
                    density,
                    DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                    recorder.surface,
                    null,
                    null,
                )

            outputPath = outputFile.absolutePath
            projectionCallback = callback
            mediaProjection = projection
            mediaRecorder = recorder
            virtualDisplay = display
            recorder.start()
            startedAtElapsedMs = SystemClock.elapsedRealtime()
            isRecording = true

            resolvePendingStart(
                mapOf<String, Any>(
                    "state" to "recording",
                ),
            )
        } catch (error: Exception) {
            cleanupProjection()
            resolvePendingStart(
                mapOf<String, Any>(
                    "state" to "failed",
                    "failureReason" to (error.message ?: "recordingStartFailed"),
                ),
            )
            stopSelf()
        }
    }

    private fun stopRecordingInternal(
        failureReason: String?,
        onComplete: ((Map<String, Any?>) -> Unit)?,
    ) {
        val durationMs =
            if (startedAtElapsedMs == 0L) {
                0
            } else {
                (SystemClock.elapsedRealtime() - startedAtElapsedMs).toInt()
            }

        var resolvedFailureReason = failureReason
        try {
            mediaRecorder?.stop()
        } catch (_: RuntimeException) {
            resolvedFailureReason = resolvedFailureReason ?: "recordingStopFailed"
            outputPath?.let { File(it).delete() }
        }

        val outputFile = outputPath?.let(::File)
        cleanupProjection()

        val payload =
            if (resolvedFailureReason == null && outputFile != null && outputFile.exists()) {
                mapOf<String, Any?>(
                    "state" to "completed",
                    "recordingKind" to "nativeScreen",
                    "durationMs" to durationMs,
                    "sourceFilePath" to outputFile.absolutePath,
                )
            } else {
                mapOf<String, Any?>(
                    "state" to "failed",
                    "failureReason" to (resolvedFailureReason ?: "recordingOutputMissing"),
                )
            }

        onComplete?.invoke(payload)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun cleanupProjection() {
        isRecording = false
        startedAtElapsedMs = 0L

        try {
            virtualDisplay?.release()
        } catch (_: Exception) {
        }
        virtualDisplay = null

        try {
            mediaRecorder?.reset()
        } catch (_: Exception) {
        }
        try {
            mediaRecorder?.release()
        } catch (_: Exception) {
        }
        mediaRecorder = null

        projectionCallback?.let { callback ->
            try {
                mediaProjection?.unregisterCallback(callback)
            } catch (_: Exception) {
            }
        }
        projectionCallback = null

        try {
            mediaProjection?.stop()
        } catch (_: Exception) {
        }
        mediaProjection = null
        outputPath = null
    }

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(getString(R.string.flutter_cockpit_recording_notification_title))
            .setContentText(getString(R.string.flutter_cockpit_recording_notification_text))
            .setSmallIcon(android.R.drawable.presence_video_online)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val manager = getSystemService(NotificationManager::class.java)
        val channel =
            NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                getString(R.string.flutter_cockpit_recording_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            )
        manager?.createNotificationChannel(channel)
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfoConstants.mediaProjectionForegroundServiceType(),
            )
            return
        }
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun intentExtraIntent(intent: Intent, key: String): Intent? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(key, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(key)
        }
    }

    private object ServiceInfoConstants {
        fun mediaProjectionForegroundServiceType(): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            } else {
                0
            }
        }
    }

    companion object {
        private const val ACTION_START = "dev.cockpit.flutter_cockpit.action.START_RECORDING"
        private const val EXTRA_RESULT_CODE = "resultCode"
        private const val EXTRA_PROJECTION_DATA = "projectionData"
        private const val EXTRA_RELATIVE_PATH = "relativePath"
        private const val NOTIFICATION_CHANNEL_ID = "flutter_cockpit_recording"
        private const val NOTIFICATION_ID = 1042

        @Volatile private var activeService: FlutterCockpitRecordingService? = null
        @Volatile private var pendingStartCallback: ((Map<String, Any?>) -> Unit)? = null

        fun requestStart(
            context: Context,
            resultCode: Int,
            projectionData: Intent,
            relativePath: String,
            onStarted: (Map<String, Any?>) -> Unit,
        ) {
            pendingStartCallback = onStarted
            val intent =
                Intent(context, FlutterCockpitRecordingService::class.java).apply {
                    action = ACTION_START
                    putExtra(EXTRA_RESULT_CODE, resultCode)
                    putExtra(EXTRA_PROJECTION_DATA, projectionData)
                    putExtra(EXTRA_RELATIVE_PATH, relativePath)
                }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stopActiveRecording(onComplete: (Map<String, Any?>) -> Unit): Boolean {
            val service = activeService ?: return false
            service.stopRecording(onComplete)
            return true
        }

        fun isRecordingActive(): Boolean = activeService?.isRecording == true

        private fun resolvePendingStart(payload: Map<String, Any?>) {
            val callback = pendingStartCallback ?: return
            pendingStartCallback = null
            callback(payload)
        }
    }
}
