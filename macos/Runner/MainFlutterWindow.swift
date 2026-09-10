import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var motionChannel: FlutterEventChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterEventChannel(
      name: "simplenameproject/window_motion",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setStreamHandler(WindowMotionStream(window: self))
    motionChannel = channel

    super.awakeFromNib()
  }
}

/// Samples during AppKit's title-bar tracking loop, including the end of a drag.
private class WindowMotionStream: NSObject, FlutterStreamHandler {
  private weak var window: NSWindow?
  private var timer: Timer?
  private var sink: FlutterEventSink?
  private var lastPosition: CGPoint?
  private var lastSampleTime: TimeInterval?
  private var stationaryFrames = 0

  init(window: NSWindow) {
    self.window = window
    super.init()
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError? {
    timer?.invalidate()
    sink = events
    lastPosition = nil
    lastSampleTime = nil
    stationaryFrames = 0
    sample()
    let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
      self?.sample()
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    timer?.invalidate()
    timer = nil
    sink = nil
    lastPosition = nil
    return nil
  }

  private func sample() {
    guard let window = window else { return }
    // Query only our window. WindowServer bounds stay current during title-bar
    // tracking, when AppKit's cached frame can lag behind the actual window.
    guard let info = CGWindowListCopyWindowInfo(
      .optionIncludingWindow, CGWindowID(window.windowNumber)
    ) as? [[String: Any]],
      let bounds = info.first?[kCGWindowBounds as String] as? [String: Any],
      let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
    else { return }
    // WindowServer and Flutter both use Y-down, in logical screen points.
    // Use the top edge so resizing the bottom isn't interpreted as movement.
    let position = frame.origin
    let time = ProcessInfo.processInfo.systemUptime
    defer { lastSampleTime = time }
    if position == lastPosition {
      stationaryFrames += 1
      // Send enough stationary samples for the Dart velocity filter to settle.
      if stationaryFrames > 24 { return }
    } else {
      if stationaryFrames > 24, let previous = lastPosition, let previousTime = lastSampleTime {
        // Re-establish a recent baseline after suppressing idle stream events.
        sink?([previous.x, previous.y, previousTime])
      }
      stationaryFrames = 0
    }
    lastPosition = position
    sink?([position.x, position.y, time])
  }

  deinit {
    timer?.invalidate()
  }
}
