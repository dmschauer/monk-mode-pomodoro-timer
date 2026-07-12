import SwiftUI

@main
struct PomodoroApp: App {
    @StateObject private var timer = TimerManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView(timer: timer)
        } label: {
            // Live countdown in the menu bar itself
            Text(timer.timeString)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window) // popover-style panel instead of a plain menu
    }
}
