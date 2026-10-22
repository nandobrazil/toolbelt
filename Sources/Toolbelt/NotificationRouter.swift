import AppKit
import UserNotifications

final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    private var categories: [String: UNNotificationCategory] = [:]
    private var handlers: [String: (String) -> Void] = [:]

    func register(_ category: UNNotificationCategory, handler: @escaping (String) -> Void) {
        categories[category.identifier] = category
        handlers[category.identifier] = handler
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories(Set(categories.values))
        center.delegate = self
    }

    func post(identifier: String, title: String, body: String, category: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = category
            center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil)) { error in
                if let error {
                    NSLog("Toolbelt: notification \(identifier) failed: \(error.localizedDescription)")
                }
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let category = response.notification.request.content.categoryIdentifier
        let action = response.actionIdentifier
        DispatchQueue.main.async { [weak self] in
            self?.handlers[category]?(action)
            completionHandler()
        }
    }
}
