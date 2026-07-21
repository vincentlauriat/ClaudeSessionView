import Foundation
import Observation

@Observable
final class UsageViewModel {
    private static let pollIntervalSeconds: TimeInterval = 5 * 60
    private static let maxBackoffSeconds: TimeInterval = 30 * 60

    var fiveHourPercent: Double?
    var fiveHourResetsAt: Date?
    var weeklyPercent: Double?
    var weeklyResetsAt: Date?
    var lastUpdated: Date?
    var errorState: UsageFetchError?
    var isLoading = false

    private var timer: Timer?
    private var currentBackoff: TimeInterval = UsageViewModel.pollIntervalSeconds

    init() {
        refresh()
    }

    func refresh() {
        isLoading = true
        UsageAPIClient.fetch { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                self.lastUpdated = Date()
                switch result {
                case .success(let usage):
                    self.errorState = nil
                    self.currentBackoff = Self.pollIntervalSeconds
                    if let fiveHour = usage.fiveHour {
                        self.fiveHourPercent = fiveHour.percent
                        self.fiveHourResetsAt = fiveHour.resetsAt
                    }
                    if let sevenDay = usage.sevenDay {
                        self.weeklyPercent = sevenDay.percent
                        self.weeklyResetsAt = sevenDay.resetsAt
                    }
                case .failure(let error):
                    self.errorState = error
                    if error == .rateLimited {
                        self.currentBackoff = min(self.currentBackoff * 2, Self.maxBackoffSeconds)
                    }
                    // On garde les dernières valeurs connues affichées, pas de reset à nil.
                }
                self.scheduleNext()
            }
        }
    }

    private func scheduleNext() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: currentBackoff, repeats: false) { [weak self] _ in
            self?.refresh()
        }
    }
}
