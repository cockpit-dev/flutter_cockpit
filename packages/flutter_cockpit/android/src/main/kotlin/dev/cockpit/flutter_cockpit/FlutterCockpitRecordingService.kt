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

private const val MIN_FINALIZABLE_RECORDING_DURATION_MS = 3_000L

internal fun recordingFinalizationDelayMillis(
    startedAtElapsedMs: Long,
    nowElapsedMs: Long,
): Long =
    (MIN_FINALIZABLE_RECORDING_DURATION_MS - (nowElapsedMs - startedAtElapsedMs))
        .coerceAtLeast(0L)

internal class FlutterCockpitRecordingService : Service() {
    private val mainHandler = Handler(Looper.getMainLooper())

    private var mediaProjection: MediaProjection? = null
    private var mediaRecorder: MediaRecorder? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var projectionCallback: MediaProjection.Callback? = null
    private var outputPath: String? = null
    private var activeSessionToken: Long? = null
    private var isRecording = false
    private var isStopping = false
    private var isFinalizing = false
    private var startedAtElapsedMs: Long = 0L

    override fun onCreate() {
        super.onCreate()
        activeService = this
        createNotificationChannel()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_START) {
            if (activeSessionToken == null && !hasPendingStart()) {
                isFinalizing = true
                stopSelf()
            }
            return START_NOT_STICKY
        }

        val sessionToken = intent.getLongExtra(EXTRA_SESSION_TOKEN, INVALID_SESSION_TOKEN)
        if (sessionToken == INVALID_SESSION_TOKEN) {
            if (activeSessionToken == null && !hasPendingStart()) {
                isFinalizing = true
                stopSelf()
            }
            return START_NOT_STICKY
        }
        if (consumeCancelledSession(sessionToken)) {
            if (activeSessionToken == null && !hasPendingStart()) {
                isFinalizing = true
                stopSelf()
            }
            return START_NOT_STICKY
        }
        if (activeSessionToken != null || isFinalizing) {
            resolvePendingStart(
                sessionToken,
                failedPayload("recordingAlreadyActive"),
            )
            return START_NOT_STICKY
        }

        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
        val projectionData = intentExtraIntent(intent, EXTRA_PROJECTION_DATA)
        val relativePath = intent.getStringExtra(EXTRA_RELATIVE_PATH)
        if (projectionData == null || relativePath == null) {
            isFinalizing = true
            resolvePendingStart(sessionToken, failedPayload("invalidStartArguments"))
            stopSelf()
            return START_NOT_STICKY
        }

        activeSessionToken = sessionToken
        startRecording(sessionToken, resultCode, projectionData, relativePath)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        val token = activeSessionToken
        val wasRecording = isRecording
        activeService = null
        isFinalizing = false
        cleanupProjection()
        if (token != null) {
            val payload = failedPayload("recordingDetached")
            val resolvedStart = resolvePendingStart(token, payload)
            if (!resolvedStart && wasRecording) {
                resolveSessionTermination(token, payload)
            } else if (!resolvedStart) {
                clearSessionTermination(token)
            }
        }
        super.onDestroy()
    }

    fun stopRecording(
        sessionToken: Long,
        onComplete: (Map<String, Any?>) -> Unit,
    ) {
        if (sessionToken != activeSessionToken || !isRecording) {
            onComplete(failedPayload("recordingNotActive"))
            return
        }
        if (isStopping) {
            onComplete(failedPayload("recordingAlreadyStopping"))
            return
        }

        isStopping = true
        isFinalizing = true
        val finalizationDelayMs =
            recordingFinalizationDelayMillis(
                startedAtElapsedMs = startedAtElapsedMs,
                nowElapsedMs = SystemClock.elapsedRealtime(),
            )
        if (finalizationDelayMs > 0L) {
            mainHandler.postDelayed(
                {
                    if (sessionToken == activeSessionToken && isRecording && isStopping) {
                        stopRecordingInternal(
                            failureReason = null,
                            onComplete = onComplete,
                        )
                    } else {
                        onComplete(failedPayload("recordingNotActive"))
                    }
                },
                finalizationDelayMs,
            )
            return
        }
        stopRecordingInternal(
            failureReason = null,
            onComplete = onComplete,
        )
    }

    fun cancelSession(sessionToken: Long) {
        if (sessionToken != activeSessionToken) {
            return
        }
        if (isRecording && !isStopping) {
            isStopping = true
            isFinalizing = true
            stopRecordingInternal(
                failureReason = "recordingDetached",
                onComplete = null,
            )
            return
        }
        isFinalizing = true
        cleanupProjection()
        stopForegroundCompat()
        stopSelf()
    }

    private fun startRecording(
        sessionToken: Long,
        resultCode: Int,
        projectionData: Intent,
        relativePath: String,
    ) {
        val outputFile =
            try {
                FlutterCockpitRecordingPathResolver.resolve(cacheDir, relativePath)
            } catch (_: Exception) {
                failStart(sessionToken, "recordingInvalidPath")
                return
            }

        try {
            val parent = outputFile.parentFile
            if (parent == null || (!parent.isDirectory && !parent.mkdirs())) {
                failStart(sessionToken, "recordingStartFailed")
                return
            }
            if (outputFile.exists() && !outputFile.delete()) {
                failStart(sessionToken, "recordingStartFailed")
                return
            }
            outputPath = outputFile.absolutePath
            startForegroundCompat(buildNotification())

            val projectionManager =
                getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
            val projection = projectionManager?.getMediaProjection(resultCode, projectionData)
            if (projection == null) {
                failStart(sessionToken, "projectionUnavailable")
                return
            }
            mediaProjection = projection

            val metrics = resources.displayMetrics
            val dimensions =
                scaledVideoDimensions(
                    metrics.widthPixels,
                    metrics.heightPixels,
                )
            val width = dimensions.first
            val height = dimensions.second
            val density = metrics.densityDpi.coerceAtLeast(1)
            val recorder = MediaRecorder()
            mediaRecorder = recorder
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
                        if (isRecording && !isStopping) {
                            isStopping = true
                            isFinalizing = true
                            stopRecordingInternal(
                                failureReason = "projectionStopped",
                                notifyCoordinator = true,
                                onComplete = null,
                            )
                        }
                    }
                }

            projectionCallback = callback
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

            virtualDisplay = display
            recorder.start()
            startedAtElapsedMs = SystemClock.elapsedRealtime()
            isRecording = true

            resolvePendingStart(
                sessionToken,
                mapOf<String, Any>("state" to "recording"),
            )
        } catch (_: Exception) {
            failStart(sessionToken, "recordingStartFailed")
        }
    }

    private fun failStart(sessionToken: Long, failureReason: String) {
        val partialOutput = outputPath?.let(::File)
        isFinalizing = true
        cleanupProjection()
        partialOutput?.delete()
        resolvePendingStart(sessionToken, failedPayload(failureReason))
        stopForegroundCompat()
        stopSelf()
    }

    private fun stopRecordingInternal(
        failureReason: String?,
        notifyCoordinator: Boolean = false,
        onComplete: ((Map<String, Any?>) -> Unit)?,
    ) {
        val sessionToken = activeSessionToken
        val durationMs =
            if (startedAtElapsedMs == 0L) {
                0
            } else {
                (SystemClock.elapsedRealtime() - startedAtElapsedMs).toInt()
            }
        val outputFile = outputPath?.let(::File)
        var resolvedFailureReason = failureReason
        var finalized = false

        try {
            val recorder = mediaRecorder
            if (recorder == null) {
                resolvedFailureReason = resolvedFailureReason ?: "recordingFinalizeFailed"
            } else {
                recorder.stop()
                finalized = true
            }
        } catch (_: RuntimeException) {
            resolvedFailureReason = resolvedFailureReason ?: "recordingFinalizeFailed"
        } finally {
            cleanupProjection()
        }

        val outputIsUsable =
            finalized && outputFile != null && outputFile.isFile && outputFile.length() > 0
        if (!outputIsUsable && resolvedFailureReason == null) {
            resolvedFailureReason = "recordingOutputMissing"
        }
        if (resolvedFailureReason != null) {
            outputFile?.delete()
        }

        val payload =
            if (resolvedFailureReason == null && outputFile != null) {
                mapOf<String, Any?>(
                    "state" to "completed",
                    "recordingKind" to "nativeScreen",
                    "effectiveLayer" to "system",
                    "durationMs" to durationMs,
                    "sourceFilePath" to outputFile.absolutePath,
                )
            } else {
                failedPayload(resolvedFailureReason ?: "recordingOutputMissing")
            }

        try {
            if (notifyCoordinator && sessionToken != null) {
                resolveSessionTermination(sessionToken, payload)
            }
            onComplete?.invoke(payload)
        } finally {
            if (!notifyCoordinator && sessionToken != null) {
                clearSessionTermination(sessionToken)
            }
            stopForegroundCompat()
            stopSelf()
        }
    }

    private fun cleanupProjection() {
        isRecording = false
        isStopping = false
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
        activeSessionToken = null
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

    private fun stopForegroundCompat() {
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } catch (_: Exception) {
        }
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

    private fun hasRunningSession(): Boolean =
        activeSessionToken != null || isFinalizing

    private fun scaledVideoDimensions(width: Int, height: Int): Pair<Int, Int> {
        val sourceWidth = width.coerceAtLeast(2)
        val sourceHeight = height.coerceAtLeast(2)
        val largest = maxOf(sourceWidth, sourceHeight)
        if (largest <= MAX_VIDEO_DIMENSION) {
            return Pair(evenDimension(sourceWidth), evenDimension(sourceHeight))
        }
        val scaledWidth = sourceWidth * MAX_VIDEO_DIMENSION / largest
        val scaledHeight = sourceHeight * MAX_VIDEO_DIMENSION / largest
        return Pair(evenDimension(scaledWidth), evenDimension(scaledHeight))
    }

    private fun evenDimension(value: Int): Int =
        (value.coerceAtLeast(2) / 2) * 2

    companion object {
        private const val ACTION_START = "dev.cockpit.flutter_cockpit.action.START_RECORDING"
        private const val EXTRA_RESULT_CODE = "resultCode"
        private const val EXTRA_PROJECTION_DATA = "projectionData"
        private const val EXTRA_RELATIVE_PATH = "relativePath"
        private const val EXTRA_SESSION_TOKEN = "sessionToken"
        private const val INVALID_SESSION_TOKEN = -1L
        private const val NOTIFICATION_CHANNEL_ID = "flutter_cockpit_recording"
        private const val NOTIFICATION_ID = 1042
        private const val MAX_VIDEO_DIMENSION = 1920

        @Volatile private var activeService: FlutterCockpitRecordingService? = null
        private var pendingStartToken: Long? = null
        private var pendingStartCallback: ((Map<String, Any?>) -> Unit)? = null
        private val sessionTerminationCallbacks =
            mutableMapOf<Long, (Map<String, Any?>) -> Unit>()
        private val cancelledSessionTokens = mutableSetOf<Long>()

        fun requestStart(
            context: Context,
            resultCode: Int,
            projectionData: Intent,
            relativePath: String,
            sessionToken: Long,
            onStarted: (Map<String, Any?>) -> Unit,
            onTerminated: (Map<String, Any?>) -> Unit,
        ) {
            synchronized(this) {
                if (pendingStartCallback != null) {
                    onStarted(failedPayload("recordingAlreadyActive"))
                    return
                }
                pendingStartToken = sessionToken
                pendingStartCallback = onStarted
                sessionTerminationCallbacks[sessionToken] = onTerminated
            }

            val intent =
                Intent(context, FlutterCockpitRecordingService::class.java).apply {
                    action = ACTION_START
                    putExtra(EXTRA_RESULT_CODE, resultCode)
                    putExtra(EXTRA_PROJECTION_DATA, projectionData)
                    putExtra(EXTRA_RELATIVE_PATH, relativePath)
                    putExtra(EXTRA_SESSION_TOKEN, sessionToken)
                }
            try {
                ContextCompat.startForegroundService(context, intent)
            } catch (_: Exception) {
                resolvePendingStart(sessionToken, failedPayload("recordingStartFailed"))
            }
        }

        fun stopActiveRecording(
            sessionToken: Long,
            onComplete: (Map<String, Any?>) -> Unit,
        ): Boolean {
            val service = activeService ?: return false
            if (service.activeSessionToken != sessionToken) {
                return false
            }
            service.stopRecording(sessionToken, onComplete)
            return true
        }

        fun cancelPendingStart(sessionToken: Long) {
            synchronized(this) {
                if (pendingStartToken == sessionToken) {
                    pendingStartToken = null
                    pendingStartCallback = null
                    sessionTerminationCallbacks.remove(sessionToken)
                    cancelledSessionTokens.add(sessionToken)
                }
            }
            activeService?.cancelSession(sessionToken)
        }

        fun hasActiveSession(): Boolean =
            synchronized(this) {
                pendingStartToken != null ||
                    sessionTerminationCallbacks.isNotEmpty() ||
                    activeService?.hasRunningSession() == true
            }

        private fun hasPendingStart(): Boolean =
            synchronized(this) {
                pendingStartToken != null
            }

        private fun consumeCancelledSession(sessionToken: Long): Boolean =
            synchronized(this) {
                cancelledSessionTokens.remove(sessionToken)
            }

        private fun resolvePendingStart(
            sessionToken: Long,
            payload: Map<String, Any?>,
        ): Boolean {
            val callback =
                synchronized(this) {
                    if (pendingStartToken != sessionToken) {
                        null
                    } else {
                        pendingStartToken = null
                        if (payload["state"] != "recording") {
                            sessionTerminationCallbacks.remove(sessionToken)
                        }
                        pendingStartCallback.also { pendingStartCallback = null }
                    }
                }
            callback?.invoke(payload)
            return callback != null
        }

        private fun resolveSessionTermination(
            sessionToken: Long,
            payload: Map<String, Any?>,
        ) {
            val callback =
                synchronized(this) {
                    sessionTerminationCallbacks.remove(sessionToken)
                }
            callback?.invoke(payload)
        }

        private fun clearSessionTermination(sessionToken: Long) {
            synchronized(this) {
                sessionTerminationCallbacks.remove(sessionToken)
            }
        }

        private fun failedPayload(failureReason: String): Map<String, Any?> =
            mapOf(
                "state" to "failed",
                "failureReason" to failureReason,
            )
    }
}
