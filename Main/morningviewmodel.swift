
import Foundation
import SwiftUI
import Combine

struct MorningTask: Identifiable, Codable {
    let id = UUID()
    var label: String
    var category: String
    var repeatDays: [Int]
    var isCompleted: Bool = false
    var backgroundImage: String
    
    var isForToday: Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1 // Adjust: Sunday=1 -> 7, Monday=2 -> 1, etc.
        return repeatDays.contains(adjustedWeekday)
    }
}

class MorningViewModel: ObservableObject {
    @Published var tasks: [MorningTask] = []
    
    init() {
        loadTasks()
    }
    
    var completedToday: Int {
        tasks.filter { $0.isForToday && $0.isCompleted }.count
    }
    
    var totalToday: Int {
        tasks.filter { $0.isForToday }.count
    }
    
    var completionPercentage: Double {
        guard totalToday > 0 else { return 0 }
        return Double(completedToday) / Double(totalToday) * 100
    }
    
    func addTask(_ task: MorningTask) {
        tasks.append(task)
        saveTasks()
    }
    
    func toggleCompleted(for task: MorningTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
            saveTasks()
        }
    }
    
    func deleteTasks(at offsets: IndexSet, in category: String) {
        var categoryTasks = tasks.filter { $0.category == category }
        categoryTasks.remove(atOffsets: offsets)
        tasks.removeAll { $0.category == category }
        tasks.append(contentsOf: categoryTasks)
        saveTasks()
    }
    
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: "morningTasks")
        }
    }
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: "morningTasks") {
            if let decoded = try? JSONDecoder().decode([MorningTask].self, from: data) {
                tasks = decoded
            }
        }
    }
}
