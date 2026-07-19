import AppKit
import AVFoundation
import CoreMedia
import CoreVideo
import FlutterMacOS

final class FlutterCockpitRecordingManager {
  init(windowProvider: @escaping () -> NSWindow?) {
    self.windowProvider = windowProvider
  }

  private let windowProvider: () -> NSWindow?
  private enum RecordingState {
    case idle
    case starting
    case recording
    case stopping
  }

  private var state: RecordingState = .idle
  private var sessionToken: UInt64 = 0
  private var activeRecorder: FlutterCockpitWindowRecorder?
  private var startedAt: Date?

  func queryCapabilities() -> [String: Any] {
    [
      "supportsNativeRecording": true,
      "preferredAcceptanceRecordingKind": "nativeScreen",
      "supportedLayers": ["app-window"],
      "preferredLayer": "app-window",
      "recordingLimitations": [
        "Native macOS recording captures the Flutter app window content only.",
        "Window chrome and other desktop surfaces are not included.",
      ],
    ]
  }

  func startRecording(arguments: [String: Any], result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      switch self.state {
      case .starting, .recording:
        result(
          FlutterError(
            code: "recordingAlreadyActive",
            message: "A recording session is already active.",
            details: nil
          )
        )
        return
      case .stopping:
        result(
          FlutterError(
            code: "recordingAlreadyStopping",
            message: "The previous recording session is still finalizing.",
            details: nil
          )
        )
        return
      case .idle:
        break
      }

      self.state = .starting
      self.sessionToken &+= 1
      let token = self.sessionToken

      guard let window = self.windowProvider() else {
        self.state = .idle
        result(
          FlutterError(
            code: "recordingNoWindow",
            message: "Native recording requires an active NSWindow.",
            details: nil
          )
        )
        return
      }

      let relativePath = arguments["relativePath"] as? String ?? "recordings/flutter_cockpit.mp4"

      do {
        let outputURL = try self.temporaryRecordingURL(relativePath: relativePath)
        try FileManager.default.createDirectory(
          at: outputURL.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        if FileManager.default.fileExists(atPath: outputURL.path) {
          try FileManager.default.removeItem(at: outputURL)
        }

        let recorder = try FlutterCockpitWindowRecorder(
          window: window,
          outputURL: outputURL
        )
        try recorder.start()
        guard token == self.sessionToken else {
          recorder.stop { _ in }
          self.state = .idle
          result(
            FlutterError(
              code: "recordingStartCancelled",
              message: "The recording session was superseded before it started.",
              details: nil
            )
          )
          return
        }
        self.activeRecorder = recorder
        self.startedAt = Date()
        self.state = .recording
        result([
          "state": "recording",
        ])
      } catch {
        self.clearSession()
        let errorCode = (error as? FlutterCockpitRecordingError)?.message == "recordingInvalidPath"
          ? "recordingInvalidPath"
          : "recordingStartFailed"
        result(
          FlutterError(
            code: errorCode,
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    }
  }

  func stopRecording(result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      guard self.state == .recording, let recorder = self.activeRecorder else {
        if self.state == .stopping {
          result(
            FlutterError(
              code: "recordingAlreadyStopping",
              message: "The previous recording session is still finalizing.",
              details: nil
            )
          )
          return
        }
        result([
          "state": "failed",
          "failureReason": "recordingNotActive",
        ])
        return
      }

      let durationMs = self.startedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
      self.state = .stopping
      let token = self.sessionToken

      recorder.stop { stopResult in
        DispatchQueue.main.async {
          guard token == self.sessionToken else {
            return
          }
          self.clearSession()
          switch stopResult {
          case let .completed(outputURL):
            result([
              "state": "completed",
              "recordingKind": "nativeScreen",
              "effectiveLayer": "app-window",
              "durationMs": durationMs,
              "sourceFilePath": outputURL.path,
            ])
          case let .failed(reason):
            result([
              "state": "failed",
              "failureReason": reason,
            ])
          }
        }
      }
    }
  }

  private func temporaryRecordingURL(relativePath: String) throws -> URL {
    let relative = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
    let components = relative.split(separator: "/", omittingEmptySubsequences: true)
    guard !relative.isEmpty,
      !relative.hasPrefix("/"),
      !relative.contains(":") && !relative.contains("\\"),
      !components.contains(where: { $0 == ".." || $0 == "." })
    else {
      throw FlutterCockpitRecordingError("recordingInvalidPath")
    }

    let temporaryRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent("flutter_cockpit_recordings", isDirectory: true)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    let outputURL = temporaryRoot.appendingPathComponent(relative).standardizedFileURL
    let rootComponents = temporaryRoot.pathComponents
    let outputComponents = outputURL.deletingLastPathComponent().pathComponents
    guard outputComponents.count >= rootComponents.count,
      Array(outputComponents.prefix(rootComponents.count)) == rootComponents
    else {
      throw FlutterCockpitRecordingError("recordingInvalidPath")
    }
    return outputURL
  }

  private func clearSession() {
    activeRecorder = nil
    startedAt = nil
    state = .idle
  }
}

private final class FlutterCockpitWindowRecorder {
  init(window: NSWindow, outputURL: URL) throws {
    self.window = window
    self.outputURL = outputURL

    guard let contentView = window.contentView else {
      throw FlutterCockpitRecordingError("Native recording requires an active contentView.")
    }

    let bounds = contentView.bounds
    guard bounds.width > 0, bounds.height > 0 else {
      throw FlutterCockpitRecordingError("Native recording requires a visible contentView.")
    }

    let backingBounds = contentView.convertToBacking(bounds)
    renderWidth = Self.evenDimension(Int(backingBounds.width.rounded(.up)))
    renderHeight = Self.evenDimension(Int(backingBounds.height.rounded(.up)))

    writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    let outputSettings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: renderWidth,
      AVVideoHeightKey: renderHeight,
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: max(renderWidth * renderHeight * 8, 2_000_000),
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
      ],
    ]
    input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
    input.expectsMediaDataInRealTime = true
    input.mediaTimeScale = frameRate
    adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        kCVPixelBufferWidthKey as String: renderWidth,
        kCVPixelBufferHeightKey as String: renderHeight,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
      ]
    )

    guard writer.canAdd(input) else {
      throw FlutterCockpitRecordingError("AVAssetWriter cannot add the macOS video input.")
    }
    writer.add(input)
  }

  private weak var window: NSWindow?
  private let outputURL: URL
  private let writer: AVAssetWriter
  private let input: AVAssetWriterInput
  private let adaptor: AVAssetWriterInputPixelBufferAdaptor
  private var timer: DispatchSourceTimer?
  private var nextFrameIndex: Int64 = 0
  private var isStopping = false
  private var capturedFrameCount = 0
  private let frameLock = NSLock()
  private var framePending = false

  private let encodeQueue = DispatchQueue(
    label: "dev.cockpit.flutter_cockpit.macos-recording"
  )

  private let renderWidth: Int
  private let renderHeight: Int

  private let frameRate: CMTimeScale = 15
  private let frameInterval: DispatchTimeInterval = .milliseconds(67)

  func start() throws {
    if !writer.startWriting() {
      throw FlutterCockpitRecordingError(
        writer.error?.localizedDescription ?? "AVAssetWriter failed to start writing."
      )
    }
    writer.startSession(atSourceTime: .zero)

    captureAndEnqueueFrame()

    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
    timer.schedule(deadline: .now() + frameInterval, repeating: frameInterval)
    timer.setEventHandler { [weak self] in
      self?.captureAndEnqueueFrame()
    }
    self.timer = timer
    timer.resume()
  }

  func stop(completion: @escaping (FlutterCockpitRecordingStopResult) -> Void) {
    guard !isStopping else {
      return
    }

    isStopping = true
    timer?.cancel()
    timer = nil

    let finalFrame = snapshotWindowImage()
    let finalPresentationTime = nextPresentationTime()

    encodeQueue.async { [self] in
      if let finalFrame {
        _ = append(cgImage: finalFrame, at: finalPresentationTime)
      }

      input.markAsFinished()
      writer.finishWriting { [self] in
        if self.writer.status == .completed,
          self.capturedFrameCount > 0,
          self.waitForRecordingFile(at: self.outputURL)
        {
          completion(.completed(self.outputURL))
          return
        }

        let failureReason = self.writer.error?.localizedDescription
          ?? (self.capturedFrameCount == 0
            ? "recordingCapturedNoFrames"
            : "recordingFinalizeFailed")
        completion(.failed(failureReason))
      }
    }
  }

  private func captureAndEnqueueFrame() {
    guard !isStopping, reserveFrame() else {
      return
    }

    guard let cgImage = snapshotWindowImage() else {
      releaseFrame()
      return
    }

    let presentationTime = nextPresentationTime()
    encodeQueue.async { [weak self] in
      guard let self else {
        return
      }
      defer { self.releaseFrame() }
      _ = self.append(cgImage: cgImage, at: presentationTime)
    }
  }

  private func reserveFrame() -> Bool {
    frameLock.lock()
    defer { frameLock.unlock() }
    guard !framePending else {
      return false
    }
    framePending = true
    return true
  }

  private func releaseFrame() {
    frameLock.lock()
    framePending = false
    frameLock.unlock()
  }

  private func snapshotWindowImage() -> CGImage? {
    guard let window, let contentView = window.contentView else {
      return nil
    }

    let bounds = contentView.bounds
    guard bounds.width > 0, bounds.height > 0 else {
      return nil
    }

    contentView.layoutSubtreeIfNeeded()
    guard let bitmap = contentView.bitmapImageRepForCachingDisplay(in: bounds) else {
      return nil
    }
    contentView.cacheDisplay(in: bounds, to: bitmap)
    return bitmap.cgImage
  }

  private func nextPresentationTime() -> CMTime {
    defer { nextFrameIndex += 1 }
    return CMTime(value: nextFrameIndex, timescale: frameRate)
  }

  private func append(cgImage: CGImage, at presentationTime: CMTime) -> Bool {
    guard writer.status == .writing else {
      return false
    }

    guard let pixelBufferPool = adaptor.pixelBufferPool else {
      return false
    }

    let readyDeadline = Date().addingTimeInterval(2)
    while !input.isReadyForMoreMediaData {
      if Date() >= readyDeadline {
        return false
      }
      Thread.sleep(forTimeInterval: 0.01)
    }

    var pixelBuffer: CVPixelBuffer?
    let createStatus = CVPixelBufferPoolCreatePixelBuffer(
      nil,
      pixelBufferPool,
      &pixelBuffer
    )
    guard createStatus == kCVReturnSuccess, let pixelBuffer else {
      return false
    }

    CVPixelBufferLockBaseAddress(pixelBuffer, [])
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      return false
    }

    guard let context = CGContext(
      data: baseAddress,
      width: renderWidth,
      height: renderHeight,
      bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue
        | CGImageAlphaInfo.premultipliedFirst.rawValue
    ) else {
      return false
    }

    context.interpolationQuality = .high
    context.setFillColor(NSColor.black.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: renderWidth, height: renderHeight))
    context.draw(
      cgImage,
      in: CGRect(x: 0, y: 0, width: renderWidth, height: renderHeight)
    )

    let appended = adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
    if appended {
      capturedFrameCount += 1
    }
    return appended
  }

  private func waitForRecordingFile(at outputURL: URL) -> Bool {
    let deadline = Date().addingTimeInterval(10)
    var lastKnownSize = 0
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

  private static func evenDimension(_ value: Int) -> Int {
    let clamped = max(value, 2)
    return clamped.isMultiple(of: 2) ? clamped : clamped + 1
  }
}

private enum FlutterCockpitRecordingStopResult {
  case completed(URL)
  case failed(String)
}

private struct FlutterCockpitRecordingError: LocalizedError {
  init(_ message: String) {
    self.message = message
  }

  let message: String

  var errorDescription: String? {
    message
  }
}
