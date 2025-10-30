
import Foundation
import SwiftUI
import Combine

struct MorningView: View {
    @ObservedObject var morningVM: MorningViewModel // Замена @EnvironmentObject
    @State private var showingAddTask = false
    @State private var newTaskLabel = ""
    @State private var newTaskCategory = ""
    @State private var selectedCategory: String? = nil
    @State private var isNewCategory = false
    @State private var selectedDays: [Bool] = Array(repeating: false, count: 7)
    @State private var isEveryDay = false
    @State private var isRange = false
    @State private var rangeStart = 1
    @State private var rangeEnd = 7
    
    // Init для получения VM
    init(morningVM: MorningViewModel) {
        self.morningVM = morningVM
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear // Убирает линию под навбаром
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Color(hex: "#00008B"))]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        ZStack {
            Image("bannerchick")
                .resizable()
                .ignoresSafeArea()
            
            NavigationView {
                Group {
                    if morningVM.tasks.isEmpty {
                        emptyView
                    } else {
                        taskListView()
                    }
                }
                .navigationTitle("Morning/Tasks")
                .navigationBarTitleDisplayMode(.inline) // Morning/Tasks и Add на одном уровне
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add") {
                            showingAddTask = true
                        }
                        .font(.headline)
                        .foregroundColor(Color(hex: "#FFD700")) // Золотой цвет для кнопки
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            addTaskSheet
        }
    }
    
    private var emptyView: some View {
        VStack {
            VStack(spacing: 12) {
                Image(systemName: "sunrise")
                    .font(.system(size: 50))
                    .foregroundColor(Color(hex: "#FFD700"))
                
                Text("Create morning tasks")
                    .font(.title3)
                    .foregroundColor(Color(hex: "#00008B"))
                
                Text("Tap 'Add' to create your first task")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5DEB3")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.9)
            )
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.2), radius: 4)
            .padding(.horizontal)
            .padding(.top, 20) // Размещаем карточку сверху
            
            Spacer() // Spacer снизу, чтобы карточка была вверху экрана
        }
    }
    
    @ViewBuilder
    private func taskListView() -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    categorySection(category: category)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color.clear)
    }
    
    private var categories: [String] {
        Array(groupedTasks.keys.sorted())
    }
    
    private var groupedTasks: [String: [MorningTask]] {
        Dictionary(grouping: morningVM.tasks, by: { $0.category })
    }
    
    @ViewBuilder
    private func categorySection(category: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category)
                .font(.headline)
                .foregroundColor(Color(hex: "#00008B"))
            
            ForEach(tasksInCategory(category), id: \.id) { task in
                taskRow(task: task)
            }
            .onDelete { offsets in
                morningVM.deleteTasks(at: offsets, in: category)
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5DEB3")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.9)
        )
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    private func tasksInCategory(_ category: String) -> [MorningTask] {
        groupedTasks[category] ?? []
    }
    
    @ViewBuilder
    private func taskRow(task: MorningTask) -> some View {
        HStack {
            Text(task.label)
                .foregroundColor(Color(hex: "#00008B"))
            Spacer()
            if task.isForToday {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        morningVM.toggleCompleted(for: task)
                    }
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(task.isCompleted ? Color(hex: "#FFA07A") : .gray)
                        .font(.title2)
                        .scaleEffect(task.isCompleted ? 1.1 : 1.0)
                }
            } else {
                Text("Not today")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            ZStack {
                Image(task.backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.8)
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5DEB3")]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.7) // Легче для подкарточек
            }
        )
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation(.easeOut(duration: 0.3)) {
                    if let index = morningVM.tasks.firstIndex(where: { $0.id == task.id }) {
                        morningVM.tasks.remove(at: index)
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    @ViewBuilder
    private var addTaskSheet: some View {
        ZStack {
            Image("bannerchick")
                .resizable()
                .ignoresSafeArea()
            
            NavigationView {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Section: Task
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Task")
                                .font(.headline)
                                .foregroundColor(Color(hex: "#00008B"))
                            TextField("Label (e.g. 'Drink water')", text: $newTaskLabel)
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5DEB3")]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .opacity(0.9)
                        )
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.2), radius: 4)
                        .frame(maxWidth: .infinity) // Убедимся в полной ширине
                        
                        // Section: Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.headline)
                                .foregroundColor(Color(hex: "#00008B"))
                            Picker("Select category", selection: $selectedCategory) {
                                ForEach(existingCategories, id: \.self) { cat in
                                    Text(cat).tag(cat as String?)
                                }
                                Text("New category").tag("new" as String?)
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedCategory) { newValue in
                                if newValue == "new" {
                                    isNewCategory = true
                                    newTaskCategory = ""
                                } else {
                                    isNewCategory = false
                                    newTaskCategory = newValue ?? ""
                                }
                            }
                            
                            if isNewCategory {
                                TextField("New category name", text: $newTaskCategory)
                            }
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5DEB3")]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .opacity(0.9)
                        )
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.2), radius: 4)
                        .frame(maxWidth: .infinity) // Полная ширина, как у других секций
                        
                        // Section: Repeats
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Repeats")
                                .font(.headline)
                                .foregroundColor(Color(hex: "#00008B"))
                            Toggle("Every Day", isOn: $isEveryDay)
                                .onChange(of: isEveryDay) { if $0 { isRange = false; selectedDays = Array(repeating: true, count: 7) } }
                            Toggle("Day Range", isOn: $isRange)
                                .onChange(of: isRange) { if $0 { isEveryDay = false; selectedDays = Array(repeating: false, count: 7) } }
                            
                            if isRange {
                                HStack {
                                    Picker("From:", selection: $rangeStart) {
                                        ForEach(1..<8, id: \.self) { day in
                                            Text(dayName(for: day)).tag(day)
                                        }
                                    }
                                    Text("–")
                                    Picker("To:", selection: $rangeEnd) {
                                        ForEach(rangeStart...7, id: \.self) { day in
                                            Text(dayName(for: day)).tag(day)
                                        }
                                    }
                                }
                            } else if !isEveryDay {
                                ForEach(0..<7, id: \.self) { index in
                                    Toggle(dayName(for: index + 1), isOn: $selectedDays[index])
                                }
                            }
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5DEB3")]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .opacity(0.9)
                        )
                        .cornerRadius(12)
                        .shadow(color: .gray.opacity(0.2), radius: 4)
                        .frame(maxWidth: .infinity) // Полная ширина
                    }
                    .padding()
                }
                .background(Color.clear)
                .navigationTitle("New Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingAddTask = false }
                            .foregroundColor(Color(hex: "#FFA07A"))
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveNewTask()
                            showingAddTask = false
                        }
                        .disabled(newTaskLabel.isEmpty || newTaskCategory.isEmpty)
                        .foregroundColor(Color(hex: "#FFD700"))
                    }
                }
                .onAppear {
                    let appearance = UINavigationBarAppearance()
                    appearance.configureWithTransparentBackground()
                    appearance.backgroundColor = .clear
                    appearance.shadowColor = .clear
                    appearance.titleTextAttributes = [.foregroundColor: UIColor(Color(hex: "#00008B"))]
                    
                    UINavigationBar.appearance().standardAppearance = appearance
                    UINavigationBar.appearance().compactAppearance = appearance
                    UINavigationBar.appearance().scrollEdgeAppearance = appearance
                }
            }
        }
    }
    
    private var existingCategories: [String] {
        Array(Set(morningVM.tasks.map { $0.category })).sorted()
    }
    
    private func saveNewTask() {
        var days: [Int] = []
        if isEveryDay {
            days = Array(1...7)
        } else if isRange {
            days = Array(rangeStart...rangeEnd)
        } else {
            for (index, isSelected) in selectedDays.enumerated() {
                if isSelected { days.append(index + 1) }
            }
        }
        
        let images = ["image1", "image2", "image3"]
        let randomImage = images.randomElement()!
        
        let newTask = MorningTask(label: newTaskLabel, category: newTaskCategory, repeatDays: days, backgroundImage: randomImage)
        morningVM.addTask(newTask)
        
        newTaskLabel = ""
        newTaskCategory = ""
        selectedCategory = nil
        isNewCategory = false
        selectedDays = Array(repeating: false, count: 7)
        isEveryDay = false
        isRange = false
    }
    
    private func dayName(for day: Int) -> String {
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return names[day - 1]
    }
}
