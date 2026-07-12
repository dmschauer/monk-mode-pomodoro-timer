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
            button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            button.title = timer.menuTitle
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let hosting = NSHostingController(rootView: ContentView(timer: timer))
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.delegate = self

        // Hop to the next runloop turn so the published change has landed.
        cancellable = timer.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.statusItem.button?.title = self.timer.menuTitle
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
        menu.addItem(NSMenuItem(title: "Quit Monk Mode Pomodoro Timer",
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
