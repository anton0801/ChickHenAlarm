
import Foundation
import SwiftUI
import Combine
import CoreMotion

struct SleepEntry: Identifiable, Codable {
    var id = UUID()
    var start: Date
    var end: Date
    var quality: Double
    var backgroundImage: String
    
    var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: start)
    }
    
    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }
    
    var durationString: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600)) / 60
        return String(format: "%02d:%02d", hours, minutes)
    }
}

class SleepViewModel: ObservableObject {
    @Published var sleepData: [SleepEntry] = []
    
    init() {
        loadSleepData()
    }
    
    // Среднее время сна (TimeInterval)
    var averageDuration: TimeInterval {
        guard !sleepData.isEmpty else { return 0 }
        return sleepData.reduce(0) { $0 + $1.duration } / Double(sleepData.count)
    }
    
    // Helper для форматирования averageDuration (поскольку extension убрали)
    var averageDurationString: String {
        let hours = Int(averageDuration) / 3600
        let minutes = Int(averageDuration.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(averageDuration.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // Среднее качество (%)
    var averageQuality: Double {
        guard !sleepData.isEmpty else { return 0 }
        return sleepData.reduce(0) { $0 + $1.quality } / Double(sleepData.count)
    }
    
    // Стабильность (% хороших ночей, >80%)
    var stability: Double {
        let goodSleeps = sleepData.filter { $0.quality > 80 }.count
        guard !sleepData.isEmpty else { return 0 }
        return Double(goodSleeps) / Double(sleepData.count) * 100
    }
    
    func addSleepEntry(_ entry: SleepEntry) {
        sleepData.append(entry)
        saveSleepData()
    }
    
    private func saveSleepData() {
        if let encoded = try? JSONEncoder().encode(sleepData) {
            UserDefaults.standard.set(encoded, forKey: "sleepData")
        }
    }
    
    private func loadSleepData() {
        if let data = UserDefaults.standard.data(forKey: "sleepData") {
            if let decoded = try? JSONDecoder().decode([SleepEntry].self, from: data) {
                sleepData = decoded
            }
        }
    }
}

struct SleepView: View {
    @ObservedObject var sleepVM: SleepViewModel
    let motionManager = CMMotionManager()
    @State private var isTracking = false
    @State private var startTime: Date?
    @State private var timer: Timer?
    @State private var currentDuration: TimeInterval = 0
    
    init(sleepVM: SleepViewModel) {
        self.sleepVM = sleepVM
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5DEB3")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Enhanced header button with icon and smooth animation
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if isTracking {
                            stopTracking()
                        } else {
                            isTracking = true
                            startTracking()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: isTracking ? "stop.fill" : "bed.double.fill")
                            .font(.title2)
                            .foregroundColor(Color(hex: "#FFD700"))
                        Text(isTracking ? "End Tracking" : "Start Sleep Tracking")
                            .font(.headline)
                            .foregroundColor(Color(hex: "#00008B"))
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "#FFD700").opacity(0.2), Color(hex: "#FFA07A").opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .gray.opacity(0.15), radius: 6, x: 0, y: 3)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                
                // Enhanced tracking card with icon and better hierarchy
                trackingCard
                
                // Enhanced header for past sessions
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.title3)
                            .foregroundColor(Color(hex: "#FFD700"))
                        Text("Past Sessions")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(hex: "#00008B"))
                        Spacer()
                        Text("\(sleepVM.sleepData.count) nights")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                
                // Improved ScrollView with enhanced cards
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(sleepVM.sleepData.reversed()) { entry in // Reversed for newest first
                            sleepEntryCard(entry: entry)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32) // Extra bottom padding for scroll end
                }
                .background(Color.clear)
                
                Spacer()
            }
        }
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if isTracking {
                startTracking()
            }
        }
    }
    
    // Enhanced tracking card with icon and gradient overlay for readability
    private var trackingCard: some View {
        Group {
            if isTracking {
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .font(.title2)
                            .foregroundColor(Color(hex: "#FFD700"))
                        Text("Sleep Tracking")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    Text(formatStartDate(startTime ?? Date()))
                        .font(.headline)
                        .foregroundColor(Color(hex: "#00008B"))
                        .multilineTextAlignment(.center)
                    Text(currentDurationString)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#FFD700"))
                        .shadow(color: .gray.opacity(0.2), radius: 2)
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 24))
                        .foregroundColor(Color(hex: "#FFA07A").opacity(0.6))
                        .rotationEffect(.degrees(90))
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isTracking)
                }
                .padding(24)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
                .shadow(color: .gray.opacity(0.2), radius: 8, x: 0, y: 4)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
    }
    
    // Enhanced individual sleep entry card with icons and better layout
    @ViewBuilder
    private func sleepEntryCard(entry: SleepEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundColor(Color(hex: "#00008B"))
                Text("Start: \(entry.formattedStartDate)")
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "#00008B"))
                Spacer()
                Image(systemName: entry.quality > 80 ? "star.fill" : entry.quality > 60 ? "star" : "star.slash")
                    .font(.title3)
                    .foregroundColor(entry.quality > 80 ? Color(hex: "#FFD700") : .gray)
            }
            
            HStack {
                Image(systemName: "clock")
                    .font(.title3)
                    .foregroundColor(Color(hex: "#FFA07A"))
                Text("Duration: \(entry.durationString)")
                    .font(.headline)
                    .foregroundColor(Color(hex: "#FFA07A"))
            }
            
            HStack {
                Image(systemName: "gauge")
                    .font(.title3)
                    .foregroundColor(.gray)
                Text("Quality: \(entry.quality, specifier: "%.0f")%")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Spacer()
                
                // Progress ring for quality
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                        .frame(width: 32, height: 32)
                    Circle()
                        .trim(from: 0, to: entry.quality / 100)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#FFA07A"), Color(hex: "#FFD700")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 32, height: 32)
                    Text("\(Int(entry.quality))%")
                        .font(.caption2)
                        .foregroundColor(Color(hex: "#00008B"))
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(20)
        .background(
            ZStack {
                Image(entry.backgroundImage)
                    .resizable()
                    .scaledToFill()
                    .opacity(0.8)
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#FFF8E7").opacity(0.95), Color(hex: "#F5DEB3").opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(16)
        .shadow(color: .gray.opacity(0.15), radius: 6, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#FFD700").opacity(0.3), lineWidth: 1)
        )
    }
    
    private var currentDurationString: String {
        let hours = Int(currentDuration) / 3600
        let minutes = Int(currentDuration.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(currentDuration.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func formatStartDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func startTracking() {
        startTime = Date()
        currentDuration = 0
        motionManager.startAccelerometerUpdates(to: .main) { data, error in
            if let data = data {
                print("Micro-movements: \(data.acceleration.x)")
            }
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = startTime {
                currentDuration = Date().timeIntervalSince(start)
            }
        }
    }
    
    private func stopTracking() {
        guard let start = startTime else { return }
        let endTime = Date()
        let duration = endTime.timeIntervalSince(start)
        
        let quality = duration > 7*3600 ? 90.0 : (duration > 6*3600 ? 80.0 : 60.0)
        
        let images = ["image1", "image2", "image3"]
        let randomImage = images.randomElement()!
        
        let newEntry = SleepEntry(start: start, end: endTime, quality: quality, backgroundImage: randomImage)
        sleepVM.addSleepEntry(newEntry)
        
        isTracking = false
        startTime = nil
        currentDuration = 0
        timer?.invalidate()
        timer = nil
        motionManager.stopAccelerometerUpdates()
    }
}
 
