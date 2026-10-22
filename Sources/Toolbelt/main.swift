import AppKit

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let appController = AppController()
appController.start()
application.run()
