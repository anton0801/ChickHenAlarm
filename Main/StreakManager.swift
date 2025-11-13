import Foundation
import Combine
import SwiftUI

class StreakManager: ObservableObject {
    static let shared = StreakManager()
    
    @Published var currentStreak: Int = 0
    @Published var longestStreak: Int = 0
    @Published var lastSuccessfulDay: Date? // дата последнего успешного дня
    @Published var goldenHourStreak: Int = 0 // отдельный счётчик для Golden Hour
    
    private let calendar = Calendar.current
    
    private init() {
        loadStreak()
    }
    
    // MARK: - Проверка, был ли сегодня уже успешный день
    var isTodayAlreadySuccessful: Bool {
        guard let last = lastSuccessfulDay else { return false }
        return calendar.isDateInToday(last)
    }
    
    // MARK: - Основная функция: завершить день как успешный
    func completeDayAsSuccessful(wasGoldenHour: Bool = false) {
        let today = calendar.startOfDay(for: Date())
        
        // Если уже засчитано сегодня — ничего не делаем
        guard !calendar.isDateInToday(lastSuccessfulDay ?? .distantPast) else { return }
        
        // Проверяем, был ли вчера успешный день (для цепочки)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        if let last = lastSuccessfulDay, calendar.isDate(last, inSameDayAs: yesterday) {
            currentStreak += 1
        } else {
            currentStreak = 1 // новая цепочка
        }
        
        if wasGoldenHour {
            goldenHourStreak += 1
        }
        
        longestStreak = max(longestStreak, currentStreak)
        lastSuccessfulDay = today
        
        saveStreak()
        checkAndUnlockRewards()
    }
    
    // MARK: - Сброс стрика (если пропустил день)
    func breakStreakIfNeeded() {
        guard let last = lastSuccessfulDay else { return }
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        
        if !calendar.isDate(last, inSameDayAs: yesterday) && !calendar.isDateInToday(last) {
            currentStreak = 0
            goldenHourStreak = 0
            saveStreak()
        }
    }
    
    // MARK: - Награды за 7, 14, 21...
    private func checkAndUnlockRewards() {
        let milestones = [7, 14, 21, 30, 50, 100]
        for milestone in milestones where currentStreak == milestone {
            unlockReward(for: milestone)
        }
    }
    
    private func unlockReward(for days: Int) {
        let rewards: [Int: (theme: String, voice: String, background: String)] = [
            7:  ("Sunrise Gold", "chik_gentle.m4a", "golden_field"),
            14: ("Midnight Blue", "chik_samurai.m4a", "night_mountains"),
            21: ("Cosmic Rooster", "chik_cosmo.m4a", "space_chick"),
            30: ("Phoenix", "chik_phoenix.m4a", "phoenix_rising")
        ]
        
        if let reward = rewards[days] {
            ThemeManager.shared.unlockTheme(reward.theme)
            // можно добавить уведомление
        }
    }
    
    var idealWakeUpTime: Date? {
        guard let sleepData = UserDefaults.standard.array(forKey: "sleepData") as? [Data],
              let entries = try? JSONDecoder().decode([SleepEntry].self, from: sleepData.first ?? Data()),
              sleepData.count >= 3 else {
            return nil
        }
        
        // Достаём все записи сна
        let allEntries: [SleepEntry] = sleepData.compactMap { data in
            try? JSONDecoder().decode(SleepEntry.self, from: data)
        }
        
        guard allEntries.count >= 3 else { return nil }
        
        let avgDuration = allEntries.reduce(0.0) { $0 + $1.duration } / Double(allEntries.count)
        let avgBedtime = allEntries.map { $0.start.timeIntervalSince1970 }
            .reduce(0, +) / Double(allEntries.count)
        
        let idealWakeUp = Date(timeIntervalSince1970: avgBedtime) + avgDuration + 8*3600 // +8 часов — идеальный сон
        return idealWakeUp
    }

    var isInGoldenHour: Bool {
        guard let ideal = idealWakeUpTime else { return false }
        let now = Date()
        let window: TimeInterval = 30 * 60 // ±30 минут
        return now >= ideal.addingTimeInterval(-window) && now <= ideal.addingTimeInterval(window)
    }
    
    // MARK: - Сохранение
    private func saveStreak() {
        UserDefaults.standard.set(currentStreak, forKey: "streak_current")
        UserDefaults.standard.set(longestStreak, forKey: "streak_longest")
        UserDefaults.standard.set(goldenHourStreak, forKey: "streak_golden")
        if let date = lastSuccessfulDay {
            UserDefaults.standard.set(date, forKey: "streak_lastDay")
        }
    }
    
    private func loadStreak() {
        currentStreak = UserDefaults.standard.integer(forKey: "streak_current")
        longestStreak = UserDefaults.standard.integer(forKey: "streak_longest")
        goldenHourStreak = UserDefaults.standard.integer(forKey: "streak_golden")
        lastSuccessfulDay = UserDefaults.standard.object(forKey: "streak_lastDay") as? Date
        
        // Автосброс при запуске, если пропущен день
        breakStreakIfNeeded()
    }
}
