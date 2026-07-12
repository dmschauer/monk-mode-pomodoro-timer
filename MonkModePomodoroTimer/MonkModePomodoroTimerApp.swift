import SwiftUI
import Combine

@main
struct MonkModePomodoroTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() } // no windows; the app lives in the status item
    }
}

// AppKit status item instead of MenuBarExtra: SwiftUI can't distinguish
// left-click (popover) from right-click (Settings/Quit menu).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let timer = TimerManager()
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cancellable: AnyCancellable?
    private var popoverLastClosed = Date.distantPast

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        updateButtonTitle()

        let hosting = NSHostingController(rootView: ContentView(timer: timer))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.delegate = self

        // Hop to the next runloop turn so the published change has landed.
        cancellable = timer.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.updateButtonTitle() }
    }

    private func updateButtonTitle() {
        guard let button = statusItem.button else { return }
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let text = timer.menuTitle
        guard timer.showPhaseInMenu else {
            button.attributedTitle = NSAttributedString(string: text, attributes: [.font: font])
            return
        }
        // The chosen tone marks the phase named in the indicator option; the
        // other phase falls back to labelColor (black in light mode, readable
        // in dark).
        let highlightsRest = timer.phaseIndicator.contains("(Rest)")
        let phaseActive = (timer.phase == .rest) == highlightsRest
        let color: NSColor = phaseActive ? restNSColor() : .labelColor
        switch timer.phaseIndicator {
        case "Emoji", "Icon":
            // Custom emoji per phase when set (first character only), else defaults.
            let custom = timer.phase == .work ? timer.workEmoji : timer.restEmoji
            let fallback = timer.phase == .work
                ? TimerManager.defaultWorkEmoji : TimerManager.defaultRestEmoji
            let emoji = custom.isEmpty ? fallback : String(custom.prefix(1))
            if timer.phaseIndicator == "Icon" {
                let image = flatEmojiImage(emoji, font: font)
                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = CGRect(x: 0, y: (font.capHeight - image.size.height) / 2,
                                           width: image.size.width, height: image.size.height)
                let title = NSMutableAttributedString(attachment: attachment)
                title.append(NSAttributedString(string: " " + text, attributes: [.font: font]))
                button.attributedTitle = title
            } else {
                button.attributedTitle = NSAttributedString(string: emoji + " " + text,
                                                            attributes: [.font: font])
            }
        case "Dot (Rest)", "Dot (Focus)":
            let title = NSMutableAttributedString(
                string: "● ", attributes: [.font: font, .foregroundColor: color])
            title.append(NSAttributedString(string: text, attributes: [.font: font]))
            button.attributedTitle = title
        default: // Color — tint only the clock; the working title stays plain
            let title = NSMutableAttributedString(
                string: timer.timeString, attributes: [.font: font, .foregroundColor: color])
            title.append(NSAttributedString(string: String(text.dropFirst(timer.timeString.count)),
                                            attributes: [.font: font]))
            button.attributedTitle = title
        }
    }

    // The emoji reduced to a flat silhouette: keep its alpha, replace every
    // pixel with the label color (black in light mode, white in dark).
    private func flatEmojiImage(_ emoji: String, font: NSFont) -> NSImage {
        let str = NSAttributedString(string: emoji, attributes: [.font: font])
        let size = str.size()
        let image = NSImage(size: size)
        image.lockFocus()
        str.draw(at: .zero)
        NSColor.labelColor.set()
        NSRect(origin: .zero, size: size).fill(using: .sourceIn)
        image.unlockFocus()
        return image
    }

    private func restNSColor() -> NSColor {
        switch timer.restColor {
        case "Sage": return NSColor(red: 0.47, green: 0.63, blue: 0.44, alpha: 1)
        case "(System)": return .controlAccentColor // the user's macOS highlight color
        case "Stone":
            // The UI's secondary (muted) tone, adapting to the menu bar's mode.
            return NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(red: 0.478, green: 0.447, blue: 0.392, alpha: 1)
                    : NSColor(red: 0.541, green: 0.514, blue: 0.459, alpha: 1)
            }
        case "Teal": return NSColor(red: 0.26, green: 0.62, blue: 0.63, alpha: 1)
        case "Monk": return NSColor(red: 0.8196, green: 0.4471, blue: 0.3216, alpha: 1)
        case "Rose": return NSColor(red: 0.80, green: 0.52, blue: 0.58, alpha: 1)
        default: return NSColor(red: 0.33, green: 0.58, blue: 0.85, alpha: 1) // Sky
        }
    }

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Monk Mode",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        // Temporarily attach the menu so the click opens it, then detach so
        // the next click fires the button action again.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if Date().timeIntervalSince(popoverLastClosed) > 0.25, // the click that dismissed it shouldn't reopen it
                  let button = statusItem.button {
            popover.appearance = forcedAppearance()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            // Don't reopen with the title field still focused/highlighted.
            popover.contentViewController?.view.window?.makeFirstResponder(nil)
        }
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in popoverLastClosed = Date() }
    }

    private func forcedAppearance() -> NSAppearance? {
        switch timer.appearance {
        case "light": return NSAppearance(named: .aqua)
        case "dark": return NSAppearance(named: .darkAqua)
        default: return nil // follow the system
        }
    }
}
