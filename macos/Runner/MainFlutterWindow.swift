import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerProcessInspector(binaryMessenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  private func registerProcessInspector(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.mirrorstages.desktop/process_inspector",
      binaryMessenger: binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "findConflictProcesses":
        result(Self.findConflictProcesses())
      case "userHomeDirectory":
        result(Self.userHomeDirectory())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func findConflictProcesses() -> [[String: Any]] {
    let keyword = "cc-switch"
    return NSWorkspace.shared.runningApplications.compactMap { app in
      let localizedName = app.localizedName ?? ""
      let bundleIdentifier = app.bundleIdentifier ?? ""
      let executablePath = app.executableURL?.path ?? ""
      let bundlePath = app.bundleURL?.path ?? ""
      let haystack = [
        localizedName,
        bundleIdentifier,
        executablePath,
        bundlePath
      ].joined(separator: " ").lowercased()

      guard haystack.contains(keyword) else {
        return nil
      }

      let command = [
        localizedName,
        bundleIdentifier,
        executablePath
      ]
        .filter { !$0.isEmpty }
        .joined(separator: " ")

      return [
        "pid": Int(app.processIdentifier),
        "command": command.isEmpty ? keyword : command
      ]
    }
  }

  private static func userHomeDirectory() -> String {
    if let homeDirectory = NSHomeDirectoryForUser(NSUserName()) {
      return homeDirectory
    }

    return FileManager.default.homeDirectoryForCurrentUser.path
  }
}
