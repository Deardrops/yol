import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  // Return false so the app stays alive as a tray icon when the window is closed.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
