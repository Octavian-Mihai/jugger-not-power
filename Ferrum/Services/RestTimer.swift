import Foundation
import Combine
import TrainingLogic
#if canImport(UIKit)
import UIKit
import AudioToolbox
#endif

@MainActor
final class RestTimer: ObservableObject {
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var totalSeconds: Int = 0
    @Published private(set) var isRunning = false

    private var endDate: Date?
    private var cancellable: AnyCancellable?
    private var didAnnounceCompletion = false

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - Double(remainingSeconds) / Double(totalSeconds)
    }

    var display: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func start(for pattern: MovementPattern) {
        start(seconds: ExerciseLibrary.restSeconds(for: pattern))
    }

    func start(seconds: Int) {
        cancellable?.cancel()
        totalSeconds = max(1, seconds)
        endDate = Date().addingTimeInterval(TimeInterval(totalSeconds))
        remainingSeconds = totalSeconds
        isRunning = true
        didAnnounceCompletion = false
        cancellable = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
        tick()
    }

    func addThirtySeconds() {
        if isRunning, let endDate {
            self.endDate = endDate.addingTimeInterval(30)
            totalSeconds += 30
            tick()
            return
        }
        start(seconds: max(30, remainingSeconds + 30))
    }

    func skip() {
        cancellable?.cancel()
        cancellable = nil
        endDate = nil
        remainingSeconds = 0
        isRunning = false
        didAnnounceCompletion = true
    }

    func reset() {
        skip()
        remainingSeconds = totalSeconds
    }

    private func tick() {
        guard let endDate else { return }
        let remaining = max(0, Int(ceil(endDate.timeIntervalSinceNow)))
        remainingSeconds = remaining
        if remaining == 0 {
            isRunning = false
            cancellable?.cancel()
            cancellable = nil
            self.endDate = nil
            if !didAnnounceCompletion {
                didAnnounceCompletion = true
                announceCompletion()
            }
        }
    }

    private func announceCompletion() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1005)
        #endif
    }
}
