import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register wallpaper method channel.
    // Must be after FlutterViewController is created so the engine's
    // binaryMessenger is available.
    let wallpaperChannel = FlutterMethodChannel(
      name: "com.example.yol_app/wallpaper",
      binaryMessenger: flutterViewController.engine.binaryMessenger)

    wallpaperChannel.setMethodCallHandler { call, result in
      if call.method == "setWallpaper" {
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(
            code: "BAD_ARGS",
            message: "Expected {path: String}",
            details: nil))
          return
        }

        let fileURL = URL(fileURLWithPath: path)
        do {
          guard let screen = NSScreen.main else {
            result(FlutterError(
              code: "NO_SCREEN",
              message: "NSScreen.main returned nil",
              details: nil))
            return
          }
          try NSWorkspace.shared.setDesktopImageURL(
            fileURL,
            for: screen,
            options: [
              // Scale proportionally and allow clipping = "Fill" mode
              .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
              .allowClipping: true,
            ])
          result(true)
        } catch {
          result(FlutterError(
            code: "SET_FAILED",
            message: error.localizedDescription,
            details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
