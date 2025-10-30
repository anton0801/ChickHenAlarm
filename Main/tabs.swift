
import SwiftUI

@main
struct ChickAlarmApp: App {
    @StateObject private var sleepVM = SleepViewModel()
    @StateObject private var morningVM = MorningViewModel()
    
    var body: some Scene {
        WindowGroup {
            TabView {
                AlarmsView()
                    .tabItem {
                        Label("Alarm", systemImage: "clock")
                    }
                SleepView(sleepVM: sleepVM)
                    .tabItem {
                        Label("Sleep", systemImage: "bed.double")
                    }
                MorningView(morningVM: morningVM) // Передача VM в init
                    .tabItem {
                        Label("Morning", systemImage: "sunrise")
                    }
                StatsView(sleepVM: sleepVM, morningVM: morningVM) // Передача в Stats
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar")
                    }
            }
            .accentColor(Color(hex: "#FFA07A")) // Мягкий оранжевый
            .preferredColorScheme(.light)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5DEB3")]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

// Extension для hex цветов
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
