import Cocoa

class NotificationPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let args = CommandLine.arguments
    var terminalBundleID = "com.mitchellh.ghostty"
    var panel: NotificationPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let envBundleID = ProcessInfo.processInfo.environment["OC_NOTIFY_TERMINAL"] {
            terminalBundleID = envBundleID
        }

        let event = args.count > 1 ? args[1] : "unknown"
        let message = args.count > 2 ? args[2] : ""
        let sessionTitle = args.count > 3 ? args[3] : ""
        let projectName = args.count > 4 ? args[4] : ""

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let ts = formatter.string(from: Date())

        let title = projectName.isEmpty ? "OpenCode" : "OpenCode — \(projectName)"
        let subtitle = sessionTitle.isEmpty ? "[\(event)] \(ts)" : "\(sessionTitle)  ·  \(ts)"
        let body = message

        NSLog("oc-notify: showing banner title=\(title)")
        showBanner(title: title, subtitle: subtitle, body: body)
    }

    func showBanner(title: String, subtitle: String, body: String) {
        guard let screen = NSScreen.main else {
            NSApp.terminate(nil)
            return
        }

        let bannerW: CGFloat = 340
        let bannerH: CGFloat = 78
        let margin: CGFloat = 12
        let screenFrame = screen.visibleFrame

        let x = screenFrame.maxX - bannerW - margin
        let y = screenFrame.maxY - bannerH - margin

        let panel = NotificationPanel(
            contentRect: NSRect(x: x, y: y, width: bannerW, height: bannerH),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: bannerW, height: bannerH))
        container.wantsLayer = true
        container.layer?.cornerRadius = 14
        container.layer?.masksToBounds = true

        let effect = NSVisualEffectView(frame: container.bounds)
        effect.material = .hudWindow
        effect.state = .active
        effect.blendingMode = .behindWindow
        effect.autoresizingMask = [.width, .height]
        container.addSubview(effect)

        let iconSize: CGFloat = 32
        let iconView = NSImageView(frame: NSRect(x: 14, y: (bannerH - iconSize) / 2, width: iconSize, height: iconSize))
        if let appIcon = NSImage(named: NSImage.applicationIconName) {
            iconView.image = appIcon
        }
        container.addSubview(iconView)

        let textX: CGFloat = 54
        let textW = bannerW - textX - 14

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.frame = NSRect(x: textX, y: bannerH - 24, width: textW, height: 16)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: subtitle)
        subtitleLabel.frame = NSRect(x: textX, y: bannerH - 42, width: textW, height: 14)
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(subtitleLabel)

        let bodyLabel = NSTextField(labelWithString: body)
        bodyLabel.frame = NSRect(x: textX, y: bannerH - 62, width: textW, height: 16)
        bodyLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        bodyLabel.textColor = .labelColor
        bodyLabel.lineBreakMode = .byTruncatingTail
        container.addSubview(bodyLabel)

        let clickButton = NSButton(frame: container.bounds)
        clickButton.isBordered = false
        clickButton.isTransparent = true
        clickButton.target = self
        clickButton.action = #selector(bannerClicked)
        container.addSubview(clickButton)

        panel.contentView = container
        self.panel = panel

        panel.alphaValue = 0
        panel.orderFront(nil)
        NSLog("oc-notify: panel shown at (\(panel.frame.origin.x), \(panel.frame.origin.y))")

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.dismissBanner()
        }
    }

    @objc func bannerClicked() {
        activateTerminal()
        dismissBanner()
    }

    func activateTerminal() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleID) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func dismissBanner() {
        guard let panel = self.panel else {
            NSApp.terminate(nil)
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: {
            panel.orderOut(nil)
            NSApp.terminate(nil)
        })
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
