import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let args = CommandLine.arguments
    var terminalBundleID = "com.mitchellh.ghostty"

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let envBundleID = ProcessInfo.processInfo.environment["OC_NOTIFY_TERMINAL"] {
            terminalBundleID = envBundleID
        }

        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: [.alert, .sound, .provisional]) { granted, error in
            NSLog("oc-notify: auth granted=\(granted) error=\(String(describing: error))")
            if let error = error {
                NSLog("oc-notify: auth error detail: \(error.localizedDescription)")
            }
            center.getNotificationSettings { settings in
                NSLog("oc-notify: authStatus=\(settings.authorizationStatus.rawValue) alertSetting=\(settings.alertSetting.rawValue)")
                DispatchQueue.main.async { self.sendNotification() }
            }
        }
    }

    func sendNotification() {
        let event = args.count > 1 ? args[1] : "unknown"
        let message = args.count > 2 ? args[2] : ""
        let sessionTitle = args.count > 3 ? args[3] : ""
        let projectName = args.count > 4 ? args[4] : ""

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())

        let content = UNMutableNotificationContent()
        content.title = projectName.isEmpty ? "OpenCode" : "OpenCode (\(projectName))"
        content.subtitle = sessionTitle.isEmpty ? "[\(event)] \(timestamp)" : sessionTitle
        content.body = "\(message) — [\(event)] \(timestamp)"
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "oc-notify-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                NSLog("oc-notify: send error: \(error.localizedDescription)")
            } else {
                NSLog("oc-notify: notification sent OK")
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSApp.terminate(nil)
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleID)
        if let url = url {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
        completionHandler()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
