import Flutter
import Foundation
import ReplayKit

final class FlutterCockpitRecordingManager {
  private enum RecordingState {
    case idle
    case starting
    case recording
    case stopping
  }

  private struct RecordingSession {
    let token: UUID
    let outputURL: URL
    let startedAt: Date
  }

  private let recorder = RPScreenRecorder.shared()
  private let fileManager = FileManager.default
  private var state: RecordingState = .idle
  private var sessionToken: UUID?
  private var session: RecordingSession?

  private var nativeRecordingAvailable: Bool {
#if targetEnvironment(simulator)
    return false
#else
    if #available(iOS 14.0, *) {
      return recorder.isAvailable
    }
    return false
#endif
  }

  func queryCapabilities() -> [String: Any] {
    if #available(iOS 14.0, *), nativeRecordingAvailable {
      return [
        "supportsNativeRecording": recorder.isAvailable,
        "preferredAcceptanceRecordingKind": "nativeScreen",
        "supportedLayers": ["system"],
        "preferredLayer": "system",
        "recordingLimitations": [
          "System recording consent is required.",
          "Protected or DRM content may not be captured.",
        ],
      ]
    }

    return [
      "supportsNativeRecording": false,
      "preferredAcceptanceRecordingKind": "nativeScreen",
      "supportedLayers": [],
      "recordingLimitations": [
        "ReplayKit recording is unavailable in the current environment.",
      ],
    ]
  }

  func startRecording(arguments: [String: Any], result: @escaping FlutterResult) {
    guard #available(iOS 14.0, *) else {
      sendError(
        result,
        code: "recordingRequiresIOS14",
        message: "Native recording requires iOS 14 or newer."
      )
      return
    }

    guard state == .idle else {
      sendError(
        result,
        code: "recordingAlreadyActive",
        message: "A recording session is already active."
      )
      return
    }

    guard nativeRecordingAvailable else {
      sendError(
        result,
        code: "recordingUnavailable",
        message: "ReplayKit recording is not available in the current environment."
      )
      return
    }

    guard let relativePath = arguments["relativePath"] as? String,
      let outputURL = validatedRecordingURL(relativePath: relativePath)
    else {
      sendError(
        result,
        code: "recordingInvalidPath",
        message: "Recording relativePath must stay within the plugin temporary root."
      )
      return
    }

    do {
      try fileManager.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      if fileManager.fileExists(atPath: outputURL.path) {
        try fileManager.removeItem(at: outputURL)
      }
    } catch {
      sendError(
        result,
        code: "recordingOutputSetupFailed",
        message: "Unable to prepare the native recording output path.",
        details: error.localizedDescription
      )
      return
    }

    let token = UUID()
    state = .starting
    sessionToken = token
    session = RecordingSession(token: token, outputURL: outputURL, startedAt: Date())
    recorder.isMicrophoneEnabled = false

    recorder.startRecording { [weak self] error in
      DispatchQueue.main.async {
        guard let self, self.sessionToken == token, self.state == .starting else {
          return
        }

        if let error {
          self.clearSession()
          self.sendError(
            result,
            code: "recordingStartFailed",
            message: "ReplayKit could not start recording.",
            details: error.localizedDescription
          )
          return
        }

        self.state = .recording
        result(["state": "recording"])
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

    switch state {
    case .idle:
      result([
        "state": "failed",
        "failureReason": "recordingNotActive",
      ])
      return
    case .starting:
      sendError(
        result,
        code: "recordingNotReady",
        message: "Recording startup is still in progress."
      )
      return
    case .stopping:
      sendError(
        result,
        code: "recordingAlreadyStopping",
        message: "Recording finalization is already in progress."
      )
      return
    case .recording:
      break
    }

    guard let session, sessionToken == session.token else {
      clearSession()
      result([
        "state": "failed",
        "failureReason": "recordingNotActive",
      ])
      return
    }

    state = .stopping
    recorder.stopRecording(withOutput: session.outputURL) { [weak self] error in
      let durationMs = Int(Date().timeIntervalSince(session.startedAt) * 1000)
      DispatchQueue.main.async {
        guard let self, self.sessionToken == session.token, self.state == .stopping else {
          return
        }

        if let error {
          self.clearSession()
          result([
            "state": "failed",
            "failureReason": "recordingFinalizeFailed",
            "failureDetail": error.localizedDescription,
          ])
          return
        }

        self.completeStopRecording(
          session: session,
          durationMs: durationMs,
          result: result
        )
      }
    }
  }

  private func completeStopRecording(
    session: RecordingSession,
    durationMs: Int,
    result: @escaping FlutterResult
  ) {
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      let fileReady = self?.waitForRecordingFile(at: session.outputURL) ?? false
      DispatchQueue.main.async {
        guard let self, self.sessionToken == session.token, self.state == .stopping else {
          return
        }
        defer { self.clearSession() }

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
          "effectiveLayer": "system",
          "durationMs": durationMs,
          "sourceFilePath": session.outputURL.path,
        ])
      }
    }
  }

  private func validatedRecordingURL(relativePath: String) -> URL? {
    let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, !trimmed.contains("\0") else {
      return nil
    }

    let driveQualified = trimmed.range(
      of: #"^[A-Za-z]:"#,
      options: .regularExpression
    ) != nil
    guard !driveQualified,
      !trimmed.hasPrefix("/"),
      !trimmed.hasPrefix("\\")
    else {
      return nil
    }

    let components = trimmed.split(whereSeparator: { $0 == "/" || $0 == "\\" })
    guard !components.isEmpty, !components.contains(where: { $0 == ".." }) else {
      return nil
    }

    let recordingRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("flutter_cockpit_recordings", isDirectory: true)
    do {
      try fileManager.createDirectory(
        at: recordingRoot,
        withIntermediateDirectories: true
      )
    } catch {
      return nil
    }

    let rootPath = recordingRoot
      .standardizedFileURL
      .resolvingSymlinksInPath()
      .path
    let candidatePath = recordingRoot
      .appendingPathComponent(trimmed)
      .standardizedFileURL
      .resolvingSymlinksInPath()
      .path
    guard candidatePath != rootPath,
      candidatePath.hasPrefix(rootPath + "/")
    else {
      return nil
    }

    return URL(fileURLWithPath: candidatePath, isDirectory: false)
  }

  private func waitForRecordingFile(at outputURL: URL) -> Bool {
    let deadline = Date().addingTimeInterval(10)
    var lastKnownSize: Int = 0
    var stableSince: Date?
    while Date() < deadline {
      if let attributes = try? fileManager.attributesOfItem(atPath: outputURL.path),
        let fileSize = attributes[.size] as? NSNumber,
        fileSize.intValue > 0
      {
        let currentSize = fileSize.intValue
        if currentSize == lastKnownSize {
          if stableSince == nil {
            stableSince = Date()
          }
          if let stableSince,
            Date().timeIntervalSince(stableSince) >= 0.4
          {
            return true
          }
        } else {
          lastKnownSize = currentSize
          stableSince = Date()
        }
      }
      Thread.sleep(forTimeInterval: 0.05)
    }
    return false
  }

  private func clearSession() {
    state = .idle
    sessionToken = nil
    session = nil
  }

  private func sendError(
    _ result: @escaping FlutterResult,
    code: String,
    message: String,
    details: String? = nil
  ) {
    result(FlutterError(code: code, message: message, details: details))
  }
}
