package dev.cockpit.flutter_cockpit

import android.app.Activity
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class FlutterCockpitPlugin : FlutterPlugin, ActivityAware {
    private lateinit var captureChannel: MethodChannel
    private lateinit var recordingChannel: MethodChannel
    private lateinit var recordingCoordinator: FlutterCockpitRecordingCoordinator
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        recordingCoordinator = FlutterCockpitRecordingCoordinator(binding.applicationContext)
        captureChannel = MethodChannel(binding.binaryMessenger, CAPTURE_CHANNEL_NAME)
        captureChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "queryNativeCaptureAvailability" -> result.success(activity != null)
                "captureAcceptanceScreenshot" -> captureAcceptanceScreenshot(result)
                else -> result.notImplemented()
            }
        }
        recordingChannel = MethodChannel(binding.binaryMessenger, RECORDING_CHANNEL_NAME)
        recordingChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "queryRecordingCapabilities" -> recordingCoordinator.queryCapabilities(result)
                "startRecording" -> recordingCoordinator.startRecording(call, result)
                "stopRecording" -> recordingCoordinator.stopRecording(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun captureAcceptanceScreenshot(result: MethodChannel.Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("noActivity", "Native capture requires an attached Activity.", null)
            return
        }

        val decorView = currentActivity.window.decorView
        val width = decorView.width
        val height = decorView.height
        if (width <= 0 || height <= 0) {
            result.error("invalidDimensions", "Activity window is not ready for capture.", null)
            return
        }

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        PixelCopy.request(currentActivity.window, bitmap, { copyResult ->
            if (copyResult != PixelCopy.SUCCESS) {
                result.error(
                    "captureFailed",
                    "PixelCopy failed with code $copyResult.",
                    null,
                )
                return@request
            }

            val stream = ByteArrayOutputStream()
            val encoded = bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            bitmap.recycle()

            if (!encoded) {
                result.error("encodeFailed", "Failed to encode native screenshot as PNG.", null)
                return@request
            }

            result.success(
                mapOf<String, Any>(
                    "bytes" to stream.toByteArray(),
                )
            )
        }, Handler(Looper.getMainLooper()))
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        captureChannel.setMethodCallHandler(null)
        recordingChannel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        recordingCoordinator.attachActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        recordingCoordinator.detachActivity()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        recordingCoordinator.attachActivity(binding)
    }

    override fun onDetachedFromActivity() {
        recordingCoordinator.detachActivity()
        activity = null
    }

    private companion object {
        const val CAPTURE_CHANNEL_NAME = "dev.cockpit.flutter_cockpit/capture"
        const val RECORDING_CHANNEL_NAME = "dev.cockpit.flutter_cockpit/recording"
    }
}
