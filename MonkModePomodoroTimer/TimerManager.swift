import AppKit
import Combine
import ServiceManagement
import UserNotifications

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
    // Decimal minutes (up to 2 places, e.g. 1.62 = 97s), converted to seconds
    // internally. Clamped: 0 would make phaseSeconds 0 (NaN progress).
    @Published var workMinutes: Double {
        didSet {
            let clamped = Self.normalized(workMinutes)
            if clamped != workMinutes { workMinutes = clamped; return }
            defaults.set(workMinutes, forKey: "workMinutes")
            applyDurationChange(to: .work)
        }
    }
    @Published var breakMinutes: Double {
        didSet {
            let clamped = Self.normalized(breakMinutes)
            if clamped != breakMinutes { breakMinutes = clamped; return }
            defaults.set(breakMinutes, forKey: "breakMinutes")
            applyDurationChange(to: .rest)
        }
    }

    // A new duration keeps the time already spent in the current phase:
    // 1 min into a session changed to 2 min leaves 1 min remaining. If more
    // has passed than the new length allows, the phase finishes immediately.
    private func applyDurationChange(to changed: Phase) {
        guard phase == changed else { return }
        let elapsed = max(0, phaseLength - secondsLeft)
        phaseLength = phaseSeconds
        let remaining = phaseLength - elapsed
        if remaining <= 0 {
            finishPhase()
        } else {
            secondsLeft = remaining
            if isRunning { endDate = Date().addingTimeInterval(Double(remaining)) }
        }
    }

    private static func normalized(_ minutes: Double) -> Double {
        min(max((minutes * 100).rounded() / 100, 0.05), 180)
    }
    @Published var sessionTarget: Int {
        didSet {
            let clamped = min(max(sessionTarget, 1), 7)
            if clamped != sessionTarget { sessionTarget = clamped; return }
            defaults.set(sessionTarget, forKey: "sessionTarget")
            if completedSessions > sessionTarget { completedSessions = sessionTarget }
        }
    }
    @Published var completedSessions: Int {
        didSet { defaults.set(completedSessions, forKey: "completedSessions") }
    }
    @Published var workingTitle: String {
        didSet { defaults.set(workingTitle, forKey: "workingTitle") }
    }
    @Published var showTitleInMenu: Bool {
        didSet { defaults.set(showTitleInMenu, forKey: "showTitleInMenu") }
    }
    @Published var showPhaseInMenu: Bool {
        didSet { defaults.set(showPhaseInMenu, forKey: "showPhaseInMenu") }
    }
    @Published var phaseIndicator: String { // see indicatorOptions
        didSet { defaults.set(phaseIndicator, forKey: "phaseIndicator") }
    }
    @Published var restColor: String { // see restColorOptions
        didSet { defaults.set(restColor, forKey: "restColor") }
    }

    @Published var workEmoji: String { // empty = default
        didSet { defaults.set(workEmoji, forKey: "workEmoji") }
    }
    @Published var restEmoji: String {
        didSet { defaults.set(restEmoji, forKey: "restEmoji") }
    }
    
    static let indicatorOptions = ["Color (Focus)", "Color (Rest)", "Dot (Focus)", "Dot (Rest)", "Emoji", "Icon"]
    static let restColorOptions = ["Monk", "Rose", "Sage", "Sky", "Stone", "Teal", "(System)"]
    static let defaultWorkEmoji = "🕯️"
    static let defaultRestEmoji = "🪨"
    @Published var appearance: String { // "light" | "dark" | "auto"
        didSet { defaults.set(appearance, forKey: "appearance") }
    }
    @Published var showSparks: Bool {
        didSet { defaults.set(showSparks, forKey: "showSparks") }
    }
    @Published var workEndSound: String {
        didSet { defaults.set(workEndSound, forKey: "workEndSound") }
    }
    @Published var breakEndSound: String {
        didSet { defaults.set(breakEndSound, forKey: "breakEndSound") }
    }
    @Published var launchAtLogin: Bool {
        didSet {
            guard !revertingLoginItem, oldValue != launchAtLogin else { return }
            do {
                if launchAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                revertingLoginItem = true
                launchAtLogin = oldValue
                revertingLoginItem = false
            }
        }
    }
    private var revertingLoginItem = false

    private let defaults = UserDefaults.standard
    private var timer: Timer?
    // Countdown is computed from a wall-clock end date, not by decrementing
    // a counter — stays correct through timer jitter and short app stalls.
    private var endDate: Date?
    // Length the current phase started with — needed to keep elapsed time
    // when the duration setting changes mid-phase.
    private var phaseLength: Int

    init() {
        let work = defaults.object(forKey: "workMinutes") != nil
            ? defaults.double(forKey: "workMinutes") : 25
        workMinutes = Self.normalized(work)
        breakMinutes = defaults.object(forKey: "breakMinutes") != nil
            ? Self.normalized(defaults.double(forKey: "breakMinutes")) : 5
        sessionTarget = min(max(defaults.object(forKey: "sessionTarget") as? Int ?? 4, 1), 7)
        completedSessions = defaults.integer(forKey: "completedSessions")
        workingTitle = defaults.string(forKey: "workingTitle") ?? ""
        showTitleInMenu = defaults.bool(forKey: "showTitleInMenu")
        showPhaseInMenu = defaults.bool(forKey: "showPhaseInMenu")
        // Migrate values stored under older option names.
        switch defaults.string(forKey: "phaseIndicator") ?? "Color" {
        case "Color": phaseIndicator = "Color (Rest)"
        case "Dot": phaseIndicator = "Dot (Rest)"
        case let other: phaseIndicator = other
        }
        switch defaults.string(forKey: "restColor") ?? "Sky" {
        case "Lavender", "System": restColor = "(System)"
        case "Grey": restColor = "Stone"
        case let other: restColor = other
        }
        workEmoji = defaults.string(forKey: "workEmoji") ?? ""
        restEmoji = defaults.string(forKey: "restEmoji") ?? ""
        appearance = defaults.string(forKey: "appearance") ?? "auto"
        showSparks = defaults.object(forKey: "showSparks") != nil
            ? defaults.bool(forKey: "showSparks") : true
        workEndSound = defaults.string(forKey: "workEndSound") ?? "Calm gong"
        breakEndSound = defaults.string(forKey: "breakEndSound") ?? "Calm gong"
        launchAtLogin = SMAppService.mainApp.status == .enabled
        let initialSeconds = max(1, Int((Self.normalized(work) * 60).rounded()))
        secondsLeft = initialSeconds
        phaseLength = initialSeconds

        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var phaseSeconds: Int {
        max(1, Int(((phase == .work ? workMinutes : breakMinutes) * 60).rounded()))
    }
    // Leading zero so the width never changes, in the menu bar or the popover.
    var timeString: String { String(format: "%02d:%02d", secondsLeft / 60, secondsLeft % 60) }
    var menuTitle: String {
        let title = workingTitle.trimmingCharacters(in: .whitespaces)
        return showTitleInMenu && !title.isEmpty ? "\(timeString) · \(title)" : timeString
    }

    func start() {
        guard !isRunning else { return }
        // Starting work on a full set begins a fresh one.
        if phase == .work && completedSessions >= sessionTarget { completedSessions = 0 }
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

    // Jump to the next phase; a skipped work session counts as completed.
    // Entering a work session with the set already full starts a fresh set,
    // same as start() does.
    func skip() {
        pause()
        if phase == .work {
            if completedSessions >= sessionTarget { completedSessions = 0 }
            creditSession()
            phase = .rest
        } else {
            phase = .work
            if completedSessions >= sessionTarget { completedSessions = 0 }
        }
        beginPhase()
    }

    // Back to a fresh work phase with an empty set.
    func resetAll() {
        pause()
        phase = .work
        completedSessions = 0
        beginPhase()
    }

    private func beginPhase() {
        secondsLeft = phaseSeconds
        phaseLength = phaseSeconds
    }

    private func creditSession() {
        completedSessions = min(completedSessions + 1, sessionTarget)
    }

    private func tick() {
        guard let end = endDate else { return }
        let remaining = end.timeIntervalSinceNow
        // Display rounds, but the phase only ends when time truly runs out —
        // finishing on the rounded value would cut the last second short and
        // flip phases while 00:01 is still showing.
        secondsLeft = max(0, Int(remaining.rounded()))
        if remaining <= 0 { finishPhase() }
    }

    // Ring position (0 = full, 1 = empty) at an arbitrary instant — sampled
    // per frame by the view for perfectly smooth motion.
    func ringFraction(at date: Date) -> Double {
        let remaining = endDate.map { $0.timeIntervalSince(date) } ?? Double(secondsLeft)
        return min(max(1 - remaining / Double(phaseSeconds), 0), 1)
    }

    private func finishPhase() {
        pause()
        if phase == .work {
            creditSession()
            playSound(workEndSound)
            notify("The bell sounds. Rest.")
            phase = .rest
        } else {
            playSound(breakEndSound)
            notify("Rest is over. Return to focus.")
            phase = .work
        }
        beginPhase()
        start() // the next phase runs by itself; only skips stay paused
    }

    static let soundOptions = ["Calm gong", "Glass", "Hero", "Ping", "Purr", "Submarine", "None"]
    private var currentSound: NSSound? // keeps playback alive; NSSound stops if deallocated

    func playSound(_ name: String) {
        currentSound?.stop()
        switch name {
        case "None":
            return
        case "Calm gong":
            guard let url = Bundle.main.url(forResource: "Gong", withExtension: "wav") else { return }
            currentSound = NSSound(contentsOf: url, byReference: true)
        default:
            currentSound = NSSound(named: name)
        }
        currentSound?.play()
    }

    // The phase-end sound plays directly, so the notification stays silent.
    private func notify(_ body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Monk Mode Pomodoro Timer"
        content.body = body
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }
}
