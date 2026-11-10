import AgentNotesCore
import SwiftUI
import UserNotifications

/// Work/break timer. All timing comes from `FocusTimer` (absolute dates), so the display is
/// correct after the app was in the background or relaunched; nothing counts ticks.
struct FocusTimerView: View {
    @State private var timer = FocusTimerView.loadTimer()
    @AppStorage("focusTimer.notify") private var notifiesAtPhaseEnd = false
    @State private var notificationsDenied = false

    private static let storageKey = "focusTimer.state"
    private static let notificationID = "focusTimer.phaseEnd"

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            // A caught-up copy for display; the stored timer is committed on user actions.
            let current = caughtUp(to: context.date)
            content(current, now: context.date)
        }
        .navigationTitle("Focus Timer")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func caughtUp(to date: Date) -> FocusTimer {
        var copy = timer
        copy.advance(to: date)
        return copy
    }

    private func content(_ current: FocusTimer, now: Date) -> some View {
        let remaining = current.remaining(at: now)
        let progress = 1 - remaining / max(current.currentPhaseDuration, 1)
        let isWork = current.phase == .work
        let phaseTitle: LocalizedStringKey = isWork ? "Focus" : "Break"
        let workMinutes = Int(timer.workDuration / 60)
        let restMinutes = Int(timer.restDuration / 60)

        return Form {
            Section {
                VStack(spacing: 20) {
                    ZStack {
                        Circle().stroke(Color.gray.opacity(0.2), lineWidth: 14)
                        Circle()
                            .trim(from: 0, to: min(max(progress, 0), 1))
                            .stroke(isWork ? Theme.accent : Color.green, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 6) {
                            Text(phaseTitle)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text(verbatim: Self.clock(remaining))
                                .font(.system(size: 56, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .accessibilityIdentifier("timer.remaining")
                        }
                    }
                    .frame(width: 260, height: 260)
                    .padding(.top, 12)

                    HStack(spacing: 16) {
                        if current.isRunning {
                            Button("Pause") { mutate { $0.pause(at: Date()) } }
                                .buttonStyle(.bordered)
                                .accessibilityIdentifier("timer.pause")
                        } else {
                            let title: LocalizedStringKey = current.isIdle ? "Start" : "Resume"
                            Button(title) { mutate { $0.start(at: Date()) } }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("timer.start")
                        }
                        Button("Reset", role: .destructive) { mutate { $0.reset() } }
                            .buttonStyle(.bordered)
                            .disabled(current.isIdle)
                    }
                    .controlSize(.large)

                    Text("Completed focus sessions: \(current.completedWorkSessions)")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                Stepper(value: minutesBinding(\.workDuration), in: 5...120, step: 5) {
                    Text("Focus: \(workMinutes) min")
                }
                Stepper(value: minutesBinding(\.restDuration), in: 1...60, step: 1) {
                    Text("Break: \(restMinutes) min")
                }
            } header: {
                Text("Session length")
            } footer: {
                Text("Lengths can be changed while the timer is stopped.")
            }
            .disabled(!current.isIdle)

            Section {
                Toggle("Notify me when a session ends", isOn: $notifiesAtPhaseEnd)
                    .onChange(of: notifiesAtPhaseEnd) { _, isOn in
                        if isOn { requestNotificationPermission() } else { cancelNotification() }
                    }
            } footer: {
                if notificationsDenied {
                    Text("Notifications are turned off for this app in the system Settings.")
                } else {
                    Text("Only the end of the current session is announced. The timer itself keeps running without notifications.")
                }
            }
        }
    }

    // MARK: State

    private func mutate(_ change: (inout FocusTimer) -> Void) {
        var updated = timer
        updated.advance(to: Date())
        change(&updated)
        timer = updated
        if let data = try? JSONEncoder().encode(updated) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
        scheduleNotification()
    }

    private func minutesBinding(_ keyPath: WritableKeyPath<FocusTimer, TimeInterval>) -> Binding<Int> {
        Binding(
            get: { Int(timer[keyPath: keyPath] / 60) },
            set: { minutes in mutate { $0[keyPath: keyPath] = TimeInterval(minutes * 60) } })
    }

    private static func loadTimer() -> FocusTimer {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(FocusTimer.self, from: data) else {
            return FocusTimer()
        }
        return saved
    }

    private static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%02ld:%02ld", total / 60, total % 60)
    }

    // MARK: Notifications (asked for only when the user turns the option on)

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationsDenied = !granted
                if granted { scheduleNotification() } else { notifiesAtPhaseEnd = false }
            }
        }
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func scheduleNotification() {
        cancelNotification()
        let now = Date()
        guard notifiesAtPhaseEnd, timer.isRunning else { return }
        let remaining = timer.remaining(at: now)
        guard remaining >= 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = timer.phase == .work
            ? String(localized: "Focus session finished")
            : String(localized: "Break finished")
        content.body = timer.phase == .work
            ? String(localized: "Time for a break.")
            : String(localized: "Time to focus again.")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger))
    }
}
