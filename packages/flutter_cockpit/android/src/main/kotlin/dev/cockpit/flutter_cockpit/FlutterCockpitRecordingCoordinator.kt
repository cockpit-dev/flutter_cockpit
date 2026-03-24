package dev.cockpit.flutter_cockpit

import android.app.Activity
import android.content.Context
import android.media.projection.MediaProjectionManager
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

internal class FlutterCockpitRecordingCoordinator(
    private val applicationContext: Context,
) : PluginRegistry.ActivityResultListener {
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingStartResult: MethodChannel.Result? = null
    private var pendingStartRequest: PendingStartRequest? = null

    fun attachActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    fun queryCapabilities(result: MethodChannel.Result) {
        result.success(
            mapOf<String, Any>(
                "supportsNativeRecording" to (activity != null),
                "preferredAcceptanceRecordingKind" to "nativeScreen",
                "recordingLimitations" to listOf(
                    "System recording consent is required.",
                    "Protected content may not be recorded.",
                ),
            ),
        )
    }

    fun startRecording(call: MethodCall, result: MethodChannel.Result) {
        if (pendingStartResult != null || FlutterCockpitRecordingService.isRecordingActive()) {
            result.error(
                "recordingAlreadyActive",
                "A recording session is already active.",
                null,
            )
            return
        }

        val currentActivity = activity
        if (currentActivity == null) {
            result.error("noActivity", "Recording requires an attached Activity.", null)
            return
        }

        val relativePath = call.argument<String>("relativePath")
        if (relativePath.isNullOrBlank()) {
            result.error("invalidArguments", "Recording relativePath is required.", null)
            return
        }

        val projectionManager =
            currentActivity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        pendingStartRequest = PendingStartRequest(relativePath = relativePath)
        pendingStartResult = result
        currentActivity.startActivityForResult(
            projectionManager.createScreenCaptureIntent(),
            REQUEST_CODE,
        )
    }

    fun stopRecording(result: MethodChannel.Result) {
        val stopped = FlutterCockpitRecordingService.stopActiveRecording { payload ->
            result.success(payload)
        }
        if (!stopped) {
            result.success(
                mapOf<String, Any>(
                    "state" to "failed",
                    "failureReason" to "recordingNotActive",
                ),
            )
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?): Boolean {
        if (requestCode != REQUEST_CODE) {
            return false
        }

        val startResult = pendingStartResult
        val startRequest = pendingStartRequest
        pendingStartResult = null
        pendingStartRequest = null

        if (startResult == null || startRequest == null) {
            return true
        }

        if (resultCode != Activity.RESULT_OK || data == null) {
            startResult.error(
                "permissionDenied",
                "User denied screen recording consent.",
                null,
            )
            return true
        }

        FlutterCockpitRecordingService.requestStart(
            context = applicationContext,
            resultCode = resultCode,
            projectionData = data,
            relativePath = startRequest.relativePath,
        ) { payload ->
            startResult.success(payload)
        }
        return true
    }

    private data class PendingStartRequest(
        val relativePath: String,
    )

    private companion object {
        const val REQUEST_CODE = 8493
    }
}
