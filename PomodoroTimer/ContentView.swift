import SwiftUI

struct ContentView: View {
    @ObservedObject var timer: TimerManager
    @State private var newTask = ""

    var body: some View {
        VStack(spacing: 14) {
            Text(timer.phase.rawValue)
                .font(.headline)
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(Color.accentColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(timer.timeString)
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 140, height: 140)
            .padding(.vertical, 4)

            HStack {
                Button(timer.isRunning ? "Pause" : "Start") {
                    timer.isRunning ? timer.pause() : timer.start()
                }
                .keyboardShortcut(.defaultAction)
                Button("Reset") { timer.reset() }
            }

            Divider()

            TextField("Add a task…", text: $newTask)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    let name = newTask.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    timer.tasks.append(TodoItem(name: name))
                    newTask = ""
                }

            ForEach($timer.tasks) { $task in
                Toggle(isOn: $task.done) {
                    Text(task.name)
                        .strikethrough(task.done)
                        .foregroundStyle(task.done ? .secondary : .primary)
                    Spacer()
                }
                .toggleStyle(.checkbox)
            }

            Divider()

            HStack {
                Text("\(timer.completedSessions) sessions done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .font(.caption)
            }
        }
        .padding()
        .frame(width: 260)
    }
}
