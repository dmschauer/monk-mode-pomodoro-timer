import Foundation
import Combine
import UserNotifications

struct TodoItem: Identifiable, Codable {
    var id = UUID()
    var name: String
    var done = false
}

@MainActor
final class TimerManager: ObservableObject {
    enum Phase: String {
        case work = "Focus"
        case rest = "Rest"
    }

    @Published var phase: Phase = .work
    @Published var isRunning = false
    @Published var secondsLeft: Int

    // Persisted settings & stats. didSet does not fire during init, so
    // loading saved values below won't re-write them.
    @Published var workMinutes: Int {
        didSet { defaults.set(workMinutes, forKey: "workMinutes") }
    }
    @Published var breakMinutes: Int {
        didSet { defaults.set(breakMinutes, forKey: "breakMinutes") }
    }
    @Published var completedSessions: Int {
        didSet { defaults.set(completedSessions, forKey: "completedSessions") }
    }
    @Published var tasks: [TodoItem] {
        didSet { defaults.set(try? JSONEncoder().encode(tasks), forKey: "tasks") }
    }

    private let defaults = UserDefaults.standard
    private var timer: Timer?
    // Countdown is computed from a wall-clock end date, not by decrementing
    // a counter — stays correct through timer jitter and short app stalls.
    private var endDate: Date?

    init() {
        let work = defaults.object(forKey: "workMinutes") as? Int ?? 25
        workMinutes = work
        breakMinutes = defaults.object(forKey: "breakMinutes") as? Int ?? 5
        completedSessions = defaults.integer(forKey: "completedSessions")
        secondsLeft = work * 60
        tasks = defaults.data(forKey: "tasks")
            .flatMap { try? JSONDecoder().decode([TodoItem].self, from: $0) } ?? []

        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var phaseSeconds: Int { (phase == .work ? workMinutes : breakMinutes) * 60 }
    var progress: Double { 1 - Double(secondsLeft) / Double(phaseSeconds) }
    var timeString: String { String(format: "%d:%02d", secondsLeft / 60, secondsLeft % 60) }

    func start() {
        guard !isRunning else { return }
        endDate = Date().addingTimeInterval(Double(secondsLeft))
        isRunning = true
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // .common so the countdown keeps ticking while the menu bar UI is open
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func pause() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        isRunning = false
    }

    func reset() {
        pause()
        secondsLeft = phaseSeconds
    }

    private func tick() {
        guard let end = endDate else { return }
        secondsLeft = max(0, Int(end.timeIntervalSinceNow.rounded()))
        if secondsLeft == 0 { finishPhase() }
    }

    private func finishPhase() {
        pause()
        if phase == .work {
            completedSessions += 1
            notify("The bell sounds. Rest.")
            phase = .rest
        } else {
            notify("Rest is over. Return to focus.")
            phase = .work
        }
        secondsLeft = phaseSeconds
    }

    private func notify(_ body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Monk Mode"
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }
}
