import Cocoa
import FlutterMacOS

public final class FlutterCockpitPlugin: NSObject, FlutterPlugin {
  private static let captureChannelName = "dev.cockpit.flutter_cockpit/capture"
  private static let recordingChannelName = "dev.cockpit.flutter_cockpit/recording"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let captureChannel = FlutterMethodChannel(
      name: captureChannelName,
      binaryMessenger: registrar.messenger
    )
    let recordingChannel = FlutterMethodChannel(
      name: recordingChannelName,
      binaryMessenger: registrar.messenger
    )
    let instance = FlutterCockpitPlugin()
    registrar.addMethodCallDelegate(instance, channel: captureChannel)
    registrar.addMethodCallDelegate(instance, channel: recordingChannel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "queryNativeCaptureAvailability":
      result(activeWindow() != nil)
    case "captureAcceptanceScreenshot":
      captureAcceptanceScreenshot(result: result)
    case "queryRecordingCapabilities":
      result([
        "supportsNativeRecording": false,
        "preferredAcceptanceRecordingKind": "nativeScreen",
        "recordingLimitations": [
          "Use the host-side macOS recording adapter for acceptance recordings."
        ],
      ])
    case "startRecording":
      result([
        "state": "failed",
        "failureReason": "hostRecordingRequired",
      ])
    case "stopRecording":
      result([
        "state": "failed",
        "failureReason": "recordingNotActive",
      ])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func captureAcceptanceScreenshot(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard let window = self.activeWindow() else {
        result(
          FlutterError(
            code: "noWindow",
            message: "Native capture requires an active NSWindow.",
            details: nil
          )
        )
        return
      }

      guard let pngData = self.captureWindowPNG(window: window) else {
        result(
          FlutterError(
            code: "encodeFailed",
            message: "Failed to encode native screenshot as PNG.",
            details: nil
          )
        )
        return
      }

      result([
        "bytes": FlutterStandardTypedData(bytes: pngData),
      ])
    }
  }

  private func activeWindow() -> NSWindow? {
    if let keyWindow = NSApp.keyWindow {
      return keyWindow
    }

    return NSApp.windows.first(where: { $0.isVisible })
  }

  private func captureWindowPNG(window: NSWindow) -> Data? {
    guard let contentView = window.contentView else {
      return nil
    }

    let bounds = contentView.bounds
    guard bounds.width > 0, bounds.height > 0 else {
      return nil
    }

    contentView.layoutSubtreeIfNeeded()
    let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds)
    guard let bitmap else {
      return nil
    }

    contentView.cacheDisplay(in: bounds, to: bitmap)
    return bitmap.representation(using: .png, properties: [:])
  }
}
