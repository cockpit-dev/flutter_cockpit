import Flutter
import ReplayKit

final class FlutterCockpitRecordingManager {
  private let recorder = RPScreenRecorder.shared()
  private var activeRelativePath: String?
  private var startedAt: Date?

  func queryCapabilities() -> [String: Any] {
    if #available(iOS 14.0, *) {
      return [
        "supportsNativeRecording": recorder.isAvailable,
        "preferredAcceptanceRecordingKind": "nativeScreen",
        "recordingLimitations": [
          "System recording consent is required.",
          "Protected or DRM content may not be captured.",
        ],
      ]
    }

    return [
      "supportsNativeRecording": false,
      "preferredAcceptanceRecordingKind": "nativeScreen",
      "recordingLimitations": [
        "Native recording requires iOS 14 or newer.",
      ],
    ]
  }

  func startRecording(arguments: [String: Any], result: @escaping FlutterResult) {
    guard #available(iOS 14.0, *) else {
      result(
        FlutterError(
          code: "recordingRequiresIOS14",
          message: "Native recording requires iOS 14 or newer.",
          details: nil
        )
      )
      return
    }

    if activeRelativePath != nil {
      result(
        FlutterError(
          code: "recordingAlreadyActive",
          message: "A recording session is already active.",
          details: nil
        )
      )
      return
    }

    guard recorder.isAvailable else {
      result(
        FlutterError(
          code: "recordingUnavailable",
          message: "ReplayKit recording is not available in the current environment.",
          details: nil
        )
      )
      return
    }

    let relativePath = arguments["relativePath"] as? String ?? "recordings/flutter_cockpit.mp4"
    recorder.isMicrophoneEnabled = false
    recorder.startRecording { [weak self] error in
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(
              code: "recordingStartFailed",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }

        self?.activeRelativePath = relativePath
        self?.startedAt = Date()
        result([
          "state": "recording",
        ])
      }
    }
  }

  func stopRecording(result: @escaping FlutterResult) {
    guard #available(iOS 14.0, *) else {
      result([
        "state": "failed",
        "failureReason": "recordingRequiresIOS14",
      ])
      return
    }

    guard let relativePath = activeRelativePath else {
      result([
        "state": "failed",
        "failureReason": "recordingNotActive",
      ])
      return
    }

    let outputURL = temporaryRecordingURL(relativePath: relativePath)
    do {
      try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      if FileManager.default.fileExists(atPath: outputURL.path) {
        try FileManager.default.removeItem(at: outputURL)
      }
    } catch {
      clearSession()
      result([
        "state": "failed",
        "failureReason": "recordingOutputSetupFailed",
      ])
      return
    }

    recorder.stopRecording(withOutput: outputURL) { [weak self] error in
      let durationMs = self?.startedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0

      if let error {
        DispatchQueue.main.async {
          self?.clearSession()
          result([
            "state": "failed",
            "failureReason": error.localizedDescription,
          ])
        }
        return
      }

      self?.completeStopRecording(
        outputURL: outputURL,
        durationMs: durationMs,
        result: result
      )
    }
  }

  private func temporaryRecordingURL(relativePath: String) -> URL {
    let temporaryRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("flutter_cockpit_recordings", isDirectory: true)
    return temporaryRoot.appendingPathComponent(relativePath)
  }

  private func completeStopRecording(
    outputURL: URL,
    durationMs: Int,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      let fileReady = self?.waitForRecordingFile(at: outputURL) ?? false
      DispatchQueue.main.async {
        defer {
          self?.clearSession()
        }

        guard fileReady else {
          result([
            "state": "failed",
            "failureReason": "recordingOutputMissing",
          ])
          return
        }

        result([
          "state": "completed",
          "recordingKind": "nativeScreen",
          "durationMs": durationMs,
          "sourceFilePath": outputURL.path,
        ])
      }
    }
  }

  private func waitForRecordingFile(at outputURL: URL) -> Bool {
    let deadline = Date().addingTimeInterval(10)
    var lastKnownSize: Int = 0
    var stableSince: Date?
    while Date() < deadline {
      if let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
        let fileSize = attributes[.size] as? NSNumber,
        fileSize.intValue > 0
      {
        let currentSize = fileSize.intValue
        if currentSize == lastKnownSize {
          if stableSince == nil {
            stableSince = Date()
          }
          if let stableSince, Date().timeIntervalSince(stableSince) >= 0.4 {
            return true
          }
        } else {
          lastKnownSize = currentSize
          stableSince = Date()
        }
      }
      Thread.sleep(forTimeInterval: 0.05)
    }

    if let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
      let fileSize = attributes[.size] as? NSNumber
    {
      return fileSize.intValue > 0
    }
    return false
  }

  private func clearSession() {
    activeRelativePath = nil
    startedAt = nil
  }
}
