import Foundation

/// A work/break focus timer whose state is defined by absolute dates, never by counting ticks.
/// It therefore stays correct when the app is suspended, backgrounded, or relaunched: on return,
/// `advance(to:)` replays every phase boundary that passed in the meantime.
public struct FocusTimer: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable {
        case work
        case rest
    }

    public var workDuration: TimeInterval
    public var restDuration: TimeInterval
    public private(set) var phase: Phase = .work
    /// When running: the moment the current phase ends.
    public private(set) var phaseEnd: Date?
    /// When paused: time left in the current phase.
    public private(set) var pausedRemaining: TimeInterval?
    public private(set) var completedWorkSessions = 0

    public init(workMinutes: Int = 25, restMinutes: Int = 5) {
        workDuration = TimeInterval(max(1, workMinutes) * 60)
        restDuration = TimeInterval(max(1, restMinutes) * 60)
    }

    public var isRunning: Bool { phaseEnd != nil }
    public var isIdle: Bool { phaseEnd == nil && pausedRemaining == nil }

    private func duration(of phase: Phase) -> TimeInterval {
        phase == .work ? workDuration : restDuration
    }

    public var currentPhaseDuration: TimeInterval { duration(of: phase) }

    public func remaining(at now: Date) -> TimeInterval {
        if let phaseEnd { return max(0, phaseEnd.timeIntervalSince(now)) }
        return pausedRemaining ?? duration(of: phase)
    }

    public mutating func start(at now: Date) {
        guard !isRunning else { return }
        phaseEnd = now.addingTimeInterval(pausedRemaining ?? duration(of: phase))
        pausedRemaining = nil
    }

    public mutating func pause(at now: Date) {
        advance(to: now)
        guard let phaseEnd else { return }
        pausedRemaining = max(0, phaseEnd.timeIntervalSince(now))
        self.phaseEnd = nil
    }

    public mutating func reset() {
        phase = .work
        phaseEnd = nil
        pausedRemaining = nil
        completedWorkSessions = 0
    }

    /// Applies every phase change that happened up to `now`. Returns how many boundaries passed.
    @discardableResult
    public mutating func advance(to now: Date) -> Int {
        var crossed = 0
        while let end = phaseEnd, end <= now {
            if phase == .work { completedWorkSessions += 1 }
            phase = phase == .work ? .rest : .work
            phaseEnd = end.addingTimeInterval(duration(of: phase))
            crossed += 1
        }
        return crossed
    }
}
