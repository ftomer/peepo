import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerShotChannel(flutterViewController)

    super.awakeFromNib()
  }

  /// Store screenshot rig, see `tools/store_shots.sh`.
  ///
  /// `integration_test/store_screenshots_test.dart` asks for an exact content
  /// size in points, so that a capture of this window is exactly the pixel size
  /// App Store Connect wants. The window also loses its title bar and floats,
  /// so nothing of the desktop ends up in the frame. Nothing calls this in an
  /// ordinary run, and the app is unchanged when nothing does.
  private func registerShotChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "peepo/shots",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      guard call.method == "sizeWindow",
            let args = call.arguments as? [String: Any],
            let w = args["width"] as? Double,
            let h = args["height"] as? Double
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.styleMask.insert(.fullSizeContentView)
      self.titlebarAppearsTransparent = true
      self.titleVisibility = .hidden
      self.standardWindowButton(.closeButton)?.isHidden = true
      self.standardWindowButton(.miniaturizeButton)?.isHidden = true
      self.standardWindowButton(.zoomButton)?.isHidden = true
      self.level = .floating
      self.setFrame(NSRect(x: 20, y: 20, width: w, height: h), display: true)
      result(true)
    }
  }
}
