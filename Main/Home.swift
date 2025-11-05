
import SwiftUI
import UserNotifications
import AVFoundation
import Speech
import CoreMotion

enum ChallengeType: String, Codable {
    case puzzle, qrScan, photo, steps, phrase
}

struct Alarm: Identifiable, Codable {
    var id = UUID()
    var time: Date
    var smartWindow: Int
    var repeatDays: [Int]
    var label: String
    var challenge: ChallengeType
    var isEnabled: Bool = true
    var backgroundImage: String
}

struct AlarmsView: View {
    @State private var alarms: [Alarm] = []
    @State private var player: AVAudioPlayer?
    @State private var showingAddAlarm = false
    @State private var newAlarmTime = Date()
    @State private var newAlarmLabel = ""
    @State private var newAlarmSmartWindow = 10
    @State private var selectedDays: [Bool] = Array(repeating: false, count: 7)
    @State private var isEveryDay = false
    @State private var isRange = false
    @State private var rangeStart = 1
    @State private var rangeEnd = 7
    @State private var newAlarmChallenge: ChallengeType = .puzzle
    @State private var newAlarmEnabled = true
    
    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear // Убирает линию под навбаром
        appearance.titleTextAttributes = [.foregroundColor: UIColor(Color(hex: "#00008B"))]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        _alarms = State(initialValue: loadAlarms())
    }
    
    var body: some View {
        ZStack {
            Image("hometime")
                .resizable()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5DEB3")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.3)
            .ignoresSafeArea()
            
            NavigationView {
                VStack(spacing: 20) {
                    Image(systemName: "rooster")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "#FFD700"))
                        .shadow(color: .gray.opacity(0.3), radius: 2)
                    
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(alarms) { alarm in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(alarm.label)
                                            .font(.headline)
                                            .foregroundColor(Color(hex: "#00008B"))
                                        Text(alarm.time, style: .time)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                        Text("Days: \(getDaysString(for: alarm))")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(get: { alarm.isEnabled }, set: { _ in toggleAlarm(alarm) }))
                                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "#FFA07A")))
                                }
                                .padding()
                                .background(
                                    ZStack {
                                        Image(alarm.backgroundImage)
                                            .resizable()
                                            .scaledToFill()
                                            .opacity(0.8)
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5DEB3")]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        .opacity(0.9)
                                    }
                                )
                                .cornerRadius(12)
                                .shadow(color: .gray.opacity(0.2), radius: 4, x: 0, y: 2)
                            }
                            .onDelete(perform: deleteAlarm)
                            
                            if alarms.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "bell.slash")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray.opacity(0.7))
                                    
                                    Text("No alarms yet")
                                        .font(.title3)
                                        .foregroundColor(Color(hex: "#00008B"))
                                    
                                    Text("Tap 'Add' to create your first alarm")
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
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                .navigationTitle("Alarms")
                .navigationBarTitleDisplayMode(.inline) // Alarms и Add на одном уровне
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Add") {
                            showingAddAlarm = true
                        }
                        .font(.headline)
                        .foregroundColor(Color(hex: "#FFD700")) // Золотой цвет для кнопки
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddAlarm) {
            addAlarmSheet
        }
        .onAppear { requestNotificationPermission() }
    }
    
    private var addAlarmSheet: some View {
        ZStack {
            Image("hometime")
                .resizable()
                .ignoresSafeArea()
            
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5DEB3")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.3)
            .ignoresSafeArea()
            
            NavigationView {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Section: Time and Window
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Time and Window")
                                .font(.headline)
                                .foregroundColor(Color(hex: "#00008B"))
                            DatePicker("Alarm Time", selection: $newAlarmTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                            Stepper("Smart Window: \(newAlarmSmartWindow) min", value: $newAlarmSmartWindow, in: 5...60)
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
                        
                        // Section: Additional
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Additional")
                                .font(.headline)
                                .foregroundColor(Color(hex: "#00008B"))
                            TextField("Label (e.g. 'Gym Time')", text: $newAlarmLabel)
                            Picker("Challenge", selection: $newAlarmChallenge) {
                                Text("Puzzle").tag(ChallengeType.puzzle)
                                Text("QR Scan").tag(ChallengeType.qrScan)
                                Text("Photo Object").tag(ChallengeType.photo)
                                Text("30 Steps").tag(ChallengeType.steps)
                                Text("Speak Phrase").tag(ChallengeType.phrase)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            Toggle("Enabled", isOn: $newAlarmEnabled)
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
                    }
                    .padding()
                }
                .navigationTitle("New Alarm")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
//                    ToolbarItem(placement: .cancellationAction) {
//                        Button("Cancel") { showingAddAlarm = false }
//                            .foregroundColor(Color(hex: "#FFA07A"))
//                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveNewAlarm()
                            showingAddAlarm = false
                        }
                        .disabled(newAlarmLabel.isEmpty)
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
    
    // Остальные функции без изменений...
    private func saveNewAlarm() {
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
        
        let newAlarm = Alarm(
            time: newAlarmTime,
            smartWindow: newAlarmSmartWindow,
            repeatDays: days,
            label: newAlarmLabel,
            challenge: newAlarmChallenge,
            isEnabled: newAlarmEnabled,
            backgroundImage: randomImage
        )
        alarms.append(newAlarm)
        
        saveAlarms()
        
        scheduleNotification(for: newAlarm)
        
        newAlarmLabel = ""
        selectedDays = Array(repeating: false, count: 7)
        isEveryDay = false
        isRange = false
    }
    
    private func scheduleNotification(for alarm: Alarm) {
        let content = UNMutableNotificationContent()
        content.title = "Wake Up! \(alarm.label)"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("soft_cock.aiff"))
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: !alarm.repeatDays.isEmpty)
        let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func getDaysString(for alarm: Alarm) -> String {
        if alarm.repeatDays.isEmpty { return "One-time" }
        let names = alarm.repeatDays.map { dayName(for: $0) }
        return names.joined(separator: ", ")
    }
    
    private func dayName(for day: Int) -> String {
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        return names[day - 1]
    }
    
    private func toggleAlarm(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index].isEnabled.toggle()
            saveAlarms()
        }
    }
    
    private func deleteAlarm(at offsets: IndexSet) {
        alarms.remove(atOffsets: offsets)
        saveAlarms()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error: \(error)")
            }
        }
    }
    
    private func saveAlarms() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: "alarms")
        }
    }
    
    private func loadAlarms() -> [Alarm] {
        if let data = UserDefaults.standard.data(forKey: "alarms") {
            if let decoded = try? JSONDecoder().decode([Alarm].self, from: data) {
                return decoded
            }
        }
        return []
    }
}
