import Foundation
import Observation

/// セッション中の学習時間を計る。バックグラウンド中は止める。
@Observable
final class StudyTimer {
    private(set) var accumulated: TimeInterval = 0
    private var startedAt: Date?
    private(set) var createdAt = Date()

    var isRunning: Bool { startedAt != nil }

    var elapsed: TimeInterval {
        accumulated + (startedAt.map { Date().timeIntervalSince($0) } ?? 0)
    }

    func start() {
        if startedAt == nil {
            startedAt = Date()
        }
    }

    func pause() {
        if let startedAt {
            accumulated += Date().timeIntervalSince(startedAt)
            self.startedAt = nil
        }
    }

    func reset() {
        accumulated = 0
        createdAt = Date()
        startedAt = createdAt
    }
}
