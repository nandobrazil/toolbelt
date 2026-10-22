import AppKit

if isatty(STDERR_FILENO) == 0 {
    let logPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Toolbelt.log").path
    freopen(logPath, "a", stderr)
}

_ = Diagnostics.launchDate

let arguments = CommandLine.arguments
if let index = arguments.firstIndex(of: AppUpdater.relaunchArgument),
   arguments.indices.contains(index + 1),
   let previousProcess = pid_t(arguments[index + 1]) {
    AppUpdater.waitForExit(of: previousProcess)
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let appController = AppController()
appController.start()
application.run()
