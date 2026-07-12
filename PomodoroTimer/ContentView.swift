import SwiftUI

// Sumi-ink palette
extension Color {
    static let ink = Color(red: 0.098, green: 0.090, blue: 0.078)   // warm charcoal
    static let paper = Color(red: 0.918, green: 0.890, blue: 0.831) // washi white
    static let ash = Color(red: 0.478, green: 0.447, blue: 0.392)   // muted labels
    static let trace = Color(red: 0.227, green: 0.212, blue: 0.184) // burned-out ring
    static let ember = Color(red: 0.788, green: 0.435, blue: 0.231) // burn tip only
}

struct ContentView: View {
    @ObservedObject var timer: TimerManager
    @State private var newTask = ""

    var body: some View {
        VStack(spacing: 16) {
            Text(timer.phase.rawValue.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(4)
                .foregroundStyle(Color.ash)

            IncenseRing(progress: timer.progress,
                        isRunning: timer.isRunning,
                        time: timer.timeString)
                .frame(width: 160, height: 160)
                .padding(.vertical, 2)

            HStack(spacing: 14) {
                Button(action: { timer.isRunning ? timer.pause() : timer.start() }) {
                    Text(timer.isRunning ? "PAUSE" : "BEGIN")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Color.paper)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .overlay(Capsule().strokeBorder(Color.ash, lineWidth: 1))
                }
                .keyboardShortcut(.defaultAction)
                Button(action: { timer.reset() }) {
                    Text("RESET")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(Color.ash)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 4) {
                TextField("", text: $newTask,
                          prompt: Text("Set your intention…").foregroundColor(Color.ash))
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.paper)
                    .tint(Color.ember)
                    .onSubmit {
                        let name = newTask.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty else { return }
                        timer.tasks.append(TodoItem(name: name))
                        newTask = ""
                    }
                Rectangle().fill(Color.trace).frame(height: 1)
            }
            .padding(.top, 4)

            ForEach($timer.tasks) { $task in
                Toggle(isOn: $task.done) {
                    Text(task.name)
                        .font(.system(size: 12))
                        .strikethrough(task.done, color: .ash)
                        .foregroundStyle(task.done ? Color.ash : Color.paper)
                }
                .toggleStyle(InkCheck())
            }

            HStack(alignment: .center) {
                // Mala beads: one per completed session in the current set of four
                HStack(spacing: 5) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < timer.completedSessions % 4 ? Color.ember : Color.trace)
                            .frame(width: 5, height: 5)
                    }
                }
                Text("\(timer.completedSessions) sessions")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.ash)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.ash)
            }
            .padding(.top, 6)
        }
        .padding(20)
        .frame(width: 260)
        .background(Color.ink)
    }
}

// A stick of incense bent into a circle: the pale remainder burns away
// clockwise, leaving a faint trace, with a glowing ember at the burn edge.
struct IncenseRing: View {
    let progress: Double // elapsed fraction, 0...1
    let isRunning: Bool
    let time: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.trace, lineWidth: 3)
            Circle()
                .trim(from: progress, to: 1)
                .stroke(Color.paper.opacity(0.85),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(Color.ember)
                .frame(width: 7, height: 7)
                .shadow(color: Color.ember.opacity(isRunning ? 0.9 : 0), radius: 6)
                .opacity(isRunning ? 1 : 0.4)
                .offset(y: -80)
                .rotationEffect(.degrees(progress * 360))
            Text(time)
                .font(.system(size: 34, weight: .light, design: .serif))
                .monospacedDigit()
                .foregroundStyle(Color.paper)
        }
    }
}

// Small ink-dot checkbox; the stock macOS checkbox breaks the aesthetic.
struct InkCheck: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(spacing: 9) {
                Circle()
                    .strokeBorder(Color.ash, lineWidth: 1)
                    .background(Circle().fill(configuration.isOn ? Color.ash : .clear).padding(3))
                    .frame(width: 13, height: 13)
                configuration.label
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}
