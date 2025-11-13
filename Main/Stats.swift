
import SwiftUI

struct StatsView: View {
    @ObservedObject var sleepVM: SleepViewModel // Замена @EnvironmentObject
    @ObservedObject var morningVM: MorningViewModel // Замена @EnvironmentObject
    
    // Init для получения VM
    init(sleepVM: SleepViewModel, morningVM: MorningViewModel) {
        self.sleepVM = sleepVM
        self.morningVM = morningVM
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5DEB3")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            GeometryReader { geometry in
                ScrollView {
                    LazyVStack(spacing: 20) {
                        sleepSection()
                        morningSection()
                        
                        statsCard(title: "Privacy", icon: "lock") {
                            VStack(spacing: 12) {
                                Button {
                                    UIApplication.shared.open(URL(string: "https://birdhenallarm.com/privacy-policy.html")!)
                                } label: {
                                    HStack {
                                        Text("Privacy Policy")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                    }
                    .padding(.horizontal, 20) // Отступ по бокам
                    .padding(.vertical, 20)
                    .frame(width: geometry.size.width) // Фиксируем ширину на всю доступную
                }
            }
        }
        .navigationTitle("Statistics")
    }
    
    @ViewBuilder
    private func sleepSection() -> some View {
        statsCard(title: "Sleep", icon: "moon.zzz.fill") {
            VStack(alignment: .leading, spacing: 8) { // Alignment .leading для левого выравнивания
                Text("Average sleep time: \(sleepVM.averageDurationString)")
                    .foregroundColor(Color(hex: "#FFA07A"))
                    .multilineTextAlignment(.leading)
                Text("Average sleep quality: \(sleepVM.averageQuality, specifier: "%.0f")%")
                    .foregroundColor(Color(hex: "#00008B"))
                    .multilineTextAlignment(.leading)
                Text("Number of trackings: \(sleepVM.sleepData.count)")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
                Text("Stability: \(sleepVM.stability, specifier: "%.0f")%")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading) // Выравниваем содержимое для равной ширины
        }
    }
    
    @ViewBuilder
    private func morningSection() -> some View {
        statsCard(title: "Morning Tasks", icon: "sunrise.fill") {
            VStack(spacing: 12) {
                Text("Completed: \(morningVM.completedToday) out of \(morningVM.totalToday)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#FFA07A"))
                Text("Percentage: \(morningVM.completionPercentage, specifier: "%.0f")%")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                ProgressView(value: morningVM.completionPercentage / 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "#FFD700")))
                    .frame(height: 10) // Улучшенный прогресс-бар для уюта
            }
            .frame(maxWidth: .infinity, alignment: .leading) // Выравниваем содержимое для равной ширины
        }
    }
    
    @ViewBuilder
    private func statsCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(Color(hex: "#FFD700"))
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color(hex: "#00008B"))
                Spacer() // Добавляем Spacer для равномерного распределения
            }
            .frame(maxWidth: .infinity, alignment: .leading) // Заголовок тоже слева
            content()
        }
        .padding(20)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5F5DC")]),
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(0.9) // Легкая прозрачность для seamless с фоном
        )
        .cornerRadius(15)
        .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2) // Мягкая тень для уюта
        .frame(maxWidth: .infinity, alignment: .center) // Одинаковая ширина для обеих карточек, центрируем
    }
}
