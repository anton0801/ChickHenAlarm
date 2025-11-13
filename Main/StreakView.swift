import SwiftUI

struct StreakView: View {
    @EnvironmentObject var streak: StreakManager
    @EnvironmentObject var theme: ThemeManager
    
    var body: some View {
        ZStack {
            theme.currentColors.background
                .ignoresSafeArea()
            
            FireParticlesBackground(isActive: streak.currentStreak > 0)
                .opacity(streak.currentStreak > 0 ? 0.6 : 0.2)
            
            ScrollView {
                VStack(spacing: 32) {
                    
                    // Main streak block
                    VStack(spacing: 20) {
                        ZStack {
                            // Progress ring (fills every 7 days)
                            Circle()
                                .trim(from: 0, to: Double(streak.currentStreak % 7) / 7.0)
                                .stroke(
                                    AngularGradient(colors: [.orange, .red, .yellow], center: .center),
                                    lineWidth: 8
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 200, height: 200)
                                .opacity(streak.currentStreak >= 7 ? 1 : 0.6)
                            
                            VStack(spacing: 8) {
                                if #available(iOS 17.0, *) {
                                    Image(systemName: streak.currentStreak >= 21 ? "crown.fill" :
                                            streak.currentStreak >= 14 ? "flame.fill" :
                                            streak.currentStreak >= 7 ? "flame" : "sparkles")
                                    .font(.system(size: 60))
                                    .foregroundColor(streak.currentStreak >= 7 ? .orange : .yellow)
                                    .symbolEffect(.pulse, options: .repeating)
                                } else {
                                    Image(systemName: streak.currentStreak >= 21 ? "crown.fill" :
                                            streak.currentStreak >= 14 ? "flame.fill" :
                                            streak.currentStreak >= 7 ? "flame" : "sparkles")
                                    .font(.system(size: 60))
                                    .foregroundColor(streak.currentStreak >= 7 ? .orange : .yellow)
                                }
                                
                                if #available(iOS 16.0, *) {
                                    Text("\(streak.currentStreak)")
                                        .font(.system(size: 90, weight: .black, design: .rounded))
                                        .foregroundColor(theme.currentColors.golden)
                                        .contentTransition(.numericText())
                                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: streak.currentStreak)
                                } else {
                                    Text("\(streak.currentStreak)")
                                        .font(.system(size: 90, weight: .black, design: .rounded))
                                        .foregroundColor(theme.currentColors.golden)
                                        .animation(.spring(response: 0.6, dampingFraction: 0.6), value: streak.currentStreak)
                                }
                                
                                Text(streak.currentStreak == 1 ? "day in a row" : "days in a row")
                                    .font(.title2)
                                    .foregroundColor(theme.currentColors.text.opacity(0.8))
                            }
                        }
                        
                        if streak.currentStreak < 100 {
                            Text("Next reward in \(7 - (streak.currentStreak % 7)) day\(7 - (streak.currentStreak % 7) == 1 ? "" : "s")")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.top, 40)
                    
                    // Golden Hour streak
                    if streak.goldenHourStreak > 0 {
                        HStack(spacing: 16) {
                            Image(systemName: "sun.max.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.yellow)
                                .shadow(color: .yellow.opacity(0.6), radius: 10)
                            
                            VStack(alignment: .leading) {
                                Text("Golden Hour Streak")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("×\(streak.goldenHourStreak)")
                                    .font(.system(size: 32, weight: .heavy))
                                    .foregroundColor(.yellow)
                            }
                            .foregroundColor(theme.currentColors.text)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.yellow.opacity(0.5), lineWidth: 2)
                        )
                    }
                    
                    // All-time record
                    VStack(spacing: 12) {
                        Text("Personal Record")
                            .font(.title3)
                            .foregroundColor(theme.currentColors.text.opacity(0.7))
                        
                        HStack(alignment: .bottom, spacing: 8) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.yellow)
                            
                            Text("\(streak.longestStreak)")
                                .font(.system(size: 64, weight: .bold))
                                .foregroundColor(.yellow)
                            
                            Text("days")
                                .font(.title2)
                                .foregroundColor(theme.currentColors.text.opacity(0.8))
                        }
                    }
                    
                    Spacer(minLength: 60)
                }
                .padding()
            }
        }
        .navigationTitle("Morning Streak")
        .navigationBarTitleDisplayMode(.large)
    }
}

// Fire particles background (unchanged – pure visuals)
struct FireParticlesBackground: View {
    @State private var animate = false
    let isActive: Bool
    
    var body: some View {
        ZStack {
            ForEach(0..<12) { i in
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundColor(.orange.opacity(0.8))
                    .offset(
                        x: CGFloat.random(in: -150...150),
                        y: animate ? -400 : 400
                    )
                    .animation(
                        Animation.linear(duration: Double.random(in: 3...6))
                            .repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.2),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}

#Preview {
    StreakView()
}
