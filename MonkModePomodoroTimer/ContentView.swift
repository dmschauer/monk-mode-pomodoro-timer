import SwiftUI

// Sumi-ink palette, one variant per color scheme. Ember is shared.
struct Theme {
    let bg: Color
    let fg: Color
    let muted: Color
    let trace: Color

    static let ember = Color(red: 0.788, green: 0.435, blue: 0.231)

    static let dark = Theme(
        bg: Color(red: 0.098, green: 0.090, blue: 0.078),    // warm charcoal
        fg: Color(red: 0.918, green: 0.890, blue: 0.831),    // washi white
        muted: Color(red: 0.478, green: 0.447, blue: 0.392),
        trace: Color(red: 0.227, green: 0.212, blue: 0.184)
    )
    static let light = Theme(
        bg: Color(red: 0.949, green: 0.933, blue: 0.894),    // washi paper
        fg: Color(red: 0.149, green: 0.137, blue: 0.118),    // ink
        muted: Color(red: 0.541, green: 0.514, blue: 0.459),
        trace: Color(red: 0.839, green: 0.812, blue: 0.753)
    )
}

struct ContentView: View {
    @ObservedObject var timer: TimerManager
    @Environment(\.colorScheme) private var systemScheme
    @State private var showSettings = false
    @State private var confirmingSkip = false
    @State private var confirmingReset = false
    @FocusState private var titleFocused: Bool

    private var forcedScheme: ColorScheme? {
        switch timer.appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil // follow the system
        }
    }

    private var theme: Theme {
        (forcedScheme ?? systemScheme) == .light ? .light : .dark
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("MONK MODE")
                .font(.system(size: 10, weight: .semibold))
                .tracking(4)
                .foregroundStyle(theme.muted)

            // Own placeholder Text instead of a prompt: macOS ignores prompt
            // colors in menu bar windows, leaving it unreadable in dark mode.
            ZStack {
                if timer.workingTitle.isEmpty {
                    Text("What are you working on?")
                        .foregroundStyle(theme.muted)
                        .allowsHitTesting(false)
                }
                TextField("", text: $timer.workingTitle)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.fg)
                    .tint(Theme.ember)
                    .focused($titleFocused)
                    .onSubmit { titleFocused = false } // Enter ends editing, no select-all
            }
            .font(.system(size: 13, weight: .medium))

            // The ring is the play/pause button.
            Button(action: { timer.isRunning ? timer.pause() : timer.start() }) {
                IncenseRing(timer: timer, theme: theme)
                    .frame(width: 160, height: 160)
                    .padding(.vertical, 2)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            .help(timer.isRunning ? "Pause (Space)" : "Start (Space)")

            HStack {
                // Mala beads: one per completed session in the current set
                HStack(spacing: 5) {
                    ForEach(0..<max(timer.sessionTarget, 1), id: \.self) { i in
                        Circle()
                            .fill(i < timer.completedSessions ? Theme.ember : theme.trace)
                            .frame(width: 5, height: 5)
                    }
                }
                Spacer()
                // First press arms the confirmation, second press skips.
                Button(action: {
                    if confirmingSkip {
                        timer.skip()
                        confirmingSkip = false
                    } else {
                        confirmingSkip = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            confirmingSkip = false
                        }
                    }
                }) {
                    // Hidden "SKIP?" reserves the wider width so the row
                    // doesn't shift when the confirmation state toggles.
                    ZStack {
                        Text("SKIP?").hidden()
                        Text(confirmingSkip ? "SKIP?" : "SKIP")
                            .foregroundStyle(confirmingSkip ? Theme.ember : theme.muted)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .help("Skip to the next phase (⌘→)")
                // Same two-step confirmation as SKIP: armed = ember.
                Button(action: {
                    if confirmingReset {
                        timer.resetAll()
                        confirmingReset = false
                    } else {
                        confirmingReset = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            confirmingReset = false
                        }
                    }
                }) {
                    ZStack {
                        Text("RESET?").hidden()
                        Text(confirmingReset ? "RESET?" : "RESET")
                            .foregroundStyle(confirmingReset ? Theme.ember : theme.muted)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                }
                .buttonStyle(.plain)
                .help("Reset timer and session count")
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                        .foregroundStyle(showSettings ? theme.fg : theme.muted)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }

            if showSettings {
                SettingsView(timer: timer, theme: theme)
            }
        }
        .padding(20)
        .frame(width: 260)
        .background(theme.bg)
        // Clicking empty space ends editing (controls handle their own clicks first).
        .contentShape(Rectangle())
        .onTapGesture { titleFocused = false }
        .preferredColorScheme(forcedScheme)
        // Accessory apps don't become active when the popover opens, so the
        // first click only focuses the window and buttons need a second one.
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}

struct SettingsView: View {
    @ObservedObject var timer: TimerManager
    let theme: Theme

    var body: some View {
        VStack(spacing: 10) {
            Rectangle().fill(theme.trace).frame(height: 1)

            MinuteRow(label: "Monk mode", value: $timer.workMinutes,
                      presets: Array(stride(from: 5, through: 60, by: 5)), theme: theme)
            MinuteRow(label: "Rest", value: $timer.breakMinutes,
                      presets: Array(1...15), theme: theme)

            HStack {
                Text("Sessions")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.muted)
                Spacer()
                Menu {
                    ForEach(1...7, id: \.self) { n in
                        Button("\(n)") { timer.sessionTarget = n }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\(timer.sessionTarget)")
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(theme.fg)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(theme.muted)
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }

            soundRow("Session ends", binding: $timer.workEndSound)
            soundRow("Rest ends", binding: $timer.breakEndSound)

            switchRow("Sparks", isOn: $timer.showSparks)

            HStack {
                Text("Appearance")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.muted)
                Spacer()
                Picker("", selection: $timer.appearance) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("Auto").tag("auto")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 140)
            }

            switchRow("Title in menu bar", isOn: $timer.showTitleInMenu)
            switchRow("Phase in menu bar", isOn: $timer.showPhaseInMenu)
            if timer.showPhaseInMenu {
                pickerRow("Indicator", options: TimerManager.indicatorOptions,
                          binding: $timer.phaseIndicator)
                if timer.phaseIndicator == "Emoji" || timer.phaseIndicator == "Icon" {
                    emojiRow("Focus emoji", binding: $timer.workEmoji,
                             fallback: TimerManager.defaultWorkEmoji)
                    emojiRow("Rest emoji", binding: $timer.restEmoji,
                             fallback: TimerManager.defaultRestEmoji)
                } else {
                    pickerRow("Color", options: TimerManager.restColorOptions,
                              binding: $timer.restColor)
                }
            }
            switchRow("Launch at login", isOn: $timer.launchAtLogin)

            Rectangle().fill(theme.trace).frame(height: 1)
        }
    }

    // Selecting a sound also previews it once.
    private func soundRow(_ label: String, binding: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)
            Spacer()
            Menu {
                ForEach(TimerManager.soundOptions, id: \.self) { name in
                    Button(name) {
                        binding.wrappedValue = name
                        timer.playSound(name)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(binding.wrappedValue)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.fg)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(theme.muted)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private func pickerRow(_ label: String, options: [String],
                           binding: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)
            Spacer()
            Menu {
                ForEach(options, id: \.self) { name in
                    Button(name) { binding.wrappedValue = name }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(binding.wrappedValue)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.fg)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(theme.muted)
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    // Empty field = use the default emoji (shown as dimmed placeholder).
    private func emojiRow(_ label: String, binding: Binding<String>,
                          fallback: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)
            Spacer()
            ZStack(alignment: .trailing) {
                if binding.wrappedValue.isEmpty {
                    Text(fallback)
                        .opacity(0.4)
                        .allowsHitTesting(false)
                }
                TextField("", text: binding)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .tint(Theme.ember)
                    .frame(width: 44)
            }
            .font(.system(size: 12))
        }
    }

    private func switchRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }

}

// Duration row: type a number, click "min" to start editing, or pick a
// preset from the chevron menu (which overrides any in-progress edit).
struct MinuteRow: View {
    let label: String
    @Binding var value: Double
    let presets: [Int]
    let theme: Theme
    @State private var focusToken = 0
    @State private var overrideToken = 0

    var body: some View {
        HStack(spacing: 6) {
            // Everything except the dropdown is one click target that starts
            // editing with the value fully selected.
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.muted)
                Spacer()
                MinuteField(value: $value, textColor: NSColor(theme.fg),
                            focusToken: focusToken, overrideToken: overrideToken)
                    .frame(width: 64)
                Text("min")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.fg)
            }
            .contentShape(Rectangle())
            .onTapGesture { focusToken += 1 }
            Menu {
                ForEach(presets, id: \.self) { m in
                    Button("\(m) min") {
                        value = Double(m)
                        overrideToken += 1 // replaces the field text even mid-edit
                    }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(theme.muted)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}

// Numeric field: any click selects the whole value so the first keystroke
// replaces it; accepts only numbers with up to two decimal places, and
// commits on Enter/focus loss.
struct MinuteField: NSViewRepresentable {
    @Binding var value: Double
    let textColor: NSColor
    var focusToken = 0    // bump to move keyboard focus into the field
    var overrideToken = 0 // bump to force the field to show `value`, even mid-edit

    static func format(_ value: Double) -> String { String(format: "%g", value) }

    func makeNSView(context: Context) -> SelectAllTextField {
        let field = SelectAllTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.alignment = .right
        field.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        field.delegate = context.coordinator
        context.coordinator.lastFocusToken = focusToken
        context.coordinator.lastOverrideToken = overrideToken
        return field
    }

    func updateNSView(_ field: SelectAllTextField, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        field.textColor = textColor
        if coordinator.lastOverrideToken != overrideToken {
            coordinator.lastOverrideToken = overrideToken
            // Setting stringValue also replaces the live editor's text, so a
            // later commit stores the picked value, not the abandoned edit.
            field.stringValue = Self.format(value)
            field.currentEditor()?.selectedRange =
                NSRange(location: (field.stringValue as NSString).length, length: 0)
        } else if field.currentEditor() == nil {
            field.stringValue = Self.format(value)
        }
        if coordinator.lastFocusToken != focusToken {
            coordinator.lastFocusToken = focusToken
            field.window?.makeFirstResponder(field)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: MinuteField
        var lastFocusToken = 0
        var lastOverrideToken = 0
        init(_ parent: MinuteField) { self.parent = parent }

        // Digits and one decimal separator ("," becomes "."), max 2 decimals.
        private func sanitize(_ s: String) -> String {
            var out = "", seenDot = false, decimals = 0
            for c in s {
                if c.isNumber {
                    if seenDot {
                        guard decimals < 2 else { continue }
                        decimals += 1
                    }
                    out.append(c)
                } else if (c == "." || c == ",") && !seenDot {
                    out.append(".")
                    seenDot = true
                }
            }
            return out
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            let clean = sanitize(field.stringValue)
            if clean != field.stringValue {
                field.stringValue = clean
                field.currentEditor()?.selectedRange =
                    NSRange(location: (clean as NSString).length, length: 0)
            }
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            if let n = Double(field.stringValue) { parent.value = n }
            field.stringValue = MinuteField.format(parent.value) // shows the clamped value
        }
    }
}

final class SelectAllTextField: NSTextField {
    private func selectAll() {
        currentEditor()?.selectedRange = NSRange(location: 0, length: (stringValue as NSString).length)
    }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { selectAll() }
        return ok
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        selectAll()
    }
}

// A stick of incense bent into a circle: the pale remainder burns away
// clockwise, leaving a faint trace, with a glowing ember at the burn edge.
// The ring position is sampled per frame from the wall clock (TimelineView),
// so motion is perfectly smooth with no keyframes to stutter between; phase
// changes and duration edits reposition it instantly.
struct IncenseRing: View {
    @ObservedObject var timer: TimerManager
    let theme: Theme

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: !timer.isRunning)) { context in
            let progress = timer.ringFraction(at: context.date)
            ZStack {
                Circle()
                    .stroke(theme.trace, lineWidth: 3)
                Circle()
                    .trim(from: progress, to: 1)
                    .stroke(theme.fg.opacity(0.85),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle()
                    .fill(Theme.ember)
                    .frame(width: 7, height: 7)
                    .shadow(color: Theme.ember.opacity(timer.isRunning ? 0.9 : 0), radius: 6)
                    .opacity(timer.isRunning ? 1 : 0.4)
                    .offset(y: -80)
                    .rotationEffect(.degrees(progress * 360))
                if timer.showSparks && timer.isRunning {
                    let t = context.date.timeIntervalSinceReferenceDate
                    let angle = progress * 2 * .pi
                    ForEach(0..<6, id: \.self) { i in
                        spark(i, t: t, emberX: 80 * sin(angle), emberY: -80 * cos(angle))
                    }
                }
                VStack(spacing: 2) {
                    Text(timer.timeString)
                        .font(.system(size: 34, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(theme.fg)
                    Text(timer.phase.rawValue.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(theme.muted)
                }
            }
        }
        // Greyed out while paused so the state is obvious at a glance.
        .opacity(timer.isRunning ? 1 : 0.45)
    }

    // Fuse sparks around the ember: each spark cycles fly-out-and-fade, fully
    // determined by the current time — no stored particle state to update.
    private func spark(_ i: Int, t: Double, emberX: Double, emberY: Double) -> some View {
        let fi = Double(i)
        let period = 0.5 + 0.4 * Self.rand(fi * 1.7)
        let phase = t / period + fi / 6
        let f = phase - floor(phase) // 0 = just emitted, 1 = burned out
        let cycle = floor(phase)     // varies direction/reach each cycle
        let direction = Self.rand(fi * 7.31 + cycle * 3.7) * 2 * .pi
        let distance = 3 + f * (6 + 6 * Self.rand(fi * 2.9 + cycle))
        let size = 0.6 + 2.2 * (1 - f)
        let hot = Self.rand(fi + cycle * 1.3) > 0.5
        return Circle()
            .fill(hot ? Color(red: 1, green: 0.75, blue: 0.35) : Theme.ember)
            .frame(width: size, height: size)
            .offset(x: emberX + cos(direction) * distance,
                    y: emberY + sin(direction) * distance)
            .opacity((1 - f) * 0.9)
    }

    private static func rand(_ n: Double) -> Double {
        abs(sin(n * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
    }
}
