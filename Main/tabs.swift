
import SwiftUI
import UIKit
import Firebase
import UserNotifications
import AppsFlyerLib
import AppTrackingTransparency

class ApplicationDelegate: UIResponder, UIApplicationDelegate, AppsFlyerLibDelegate, MessagingDelegate, UNUserNotificationCenterDelegate, DeepLinkDelegate {
    
    private var attrData: [AnyHashable: Any] = [:]
    private let trackingActivationKey = UIApplication.didBecomeActiveNotification
    
    private var deepLinkClickEvent: [AnyHashable: Any] = [:]
    private let hasSentAttributionKey = "hasSentAttributionData"
    private let timerKey = "deepLinkMergeTimer"
    
    private var mergeTimer: Timer?
    
    
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        extractNeededDataFromPush(from: userInfo)
        completionHandler(.newData)
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        setupPushInfrastructure()
        bootstrapAppsFlyer()
        
        if let remotePayload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            extractNeededDataFromPush(from: remotePayload)
        }
        
        observeAppActivation()
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        messaging.token { [weak self] token, error in
            guard error == nil, let token = token else { return }
            UserDefaults.standard.set(token, forKey: "fcm_token")
            UserDefaults.standard.set(token, forKey: "push_token")
        }
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let payload = notification.request.content.userInfo
        extractNeededDataFromPush(from: payload)
        completionHandler([.banner, .sound])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        extractNeededDataFromPush(from: response.notification.request.content.userInfo)
        completionHandler()
    }
    
    private func fireMergedTimer() {
        mergeTimer?.invalidate()
        mergeTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.sendMergedDataTOSplash()
        }
    }
    
    @objc private func triggerTracking() {
        if #available(iOS 14.0, *) {
            AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async {
                    AppsFlyerLib.shared().start()
                }
            }
        }
    }
    
    func onConversionDataSuccess(_ data: [AnyHashable: Any]) {
        attrData = data
        fireMergedTimer()
        sendMergedDataTOSplash()
    }
    
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard case .found = result.status,
              let deepLinkObj = result.deepLink else { return }
        
        guard !UserDefaults.standard.bool(forKey: hasSentAttributionKey) else { return }
        
        deepLinkClickEvent = deepLinkObj.clickEvent
        
        NotificationCenter.default.post(name: Notification.Name("deeplink_values"), object: nil, userInfo: ["deeplinksData": deepLinkClickEvent])
        
        mergeTimer?.invalidate()
        
        sendMergedDataTOSplash()
    }
    
    func onConversionDataFail(_ error: Error) {
        print("AppsFlyer attribution failed: \(error.localizedDescription)")
        broadcastAttributionUpdate(data: [:])
    }
    
    // MARK: - Private Setup
    private func setupPushInfrastructure() {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    private func bootstrapAppsFlyer() {
        AppsFlyerLib.shared().appsFlyerDevKey = AppConstants.appsFlyerDevKey
        AppsFlyerLib.shared().appleAppID = AppConstants.appsFlyerAppID
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().deepLinkDelegate = self
    }
    
    private func observeAppActivation() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(triggerTracking),
            name: trackingActivationKey,
            object: nil
        )
    }
    
    private func extractNeededDataFromPush(from payload: [AnyHashable: Any]) {
        var pushRefreshubal: String?
        if let url = payload["url"] as? String {
            pushRefreshubal = url
        } else if let data = payload["data"] as? [String: Any],
                  let url = data["url"] as? String {
            pushRefreshubal = url
        }
        if let link = pushRefreshubal {
            UserDefaults.standard.set(link, forKey: "temp_url")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                NotificationCenter.default.post(
                    name: NSNotification.Name("LoadTempURL"),
                    object: nil,
                    userInfo: ["temp_url": link]
                )
            }
        }
    }
    
}

extension ApplicationDelegate {
    
    
    func sendMergedDataTOSplash() {
        var mergedAttrData = attrData
        for (key, value) in deepLinkClickEvent {
            if mergedAttrData[key] == nil {
                mergedAttrData[key] = value
            }
        }
        broadcastAttributionUpdate(data: mergedAttrData)
        UserDefaults.standard.set(true, forKey: hasSentAttributionKey)
        attrData = [:]
        deepLinkClickEvent = [:]
        mergeTimer?.invalidate()
    }
    
    func broadcastAttributionUpdate(data: [AnyHashable: Any]) {
        NotificationCenter.default.post(
            name: Notification.Name("ConversionDataReceived"),
            object: nil,
            userInfo: ["conversionData": data]
        )
    }
    
}


@main
struct ChickAlarmApp: App {
    
    @UIApplicationDelegateAdaptor(ApplicationDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            SplashScreen()
        }
    }
}

struct MainView: View {
    
    @StateObject private var sleepVM = SleepViewModel()
    @StateObject private var morningVM = MorningViewModel()
    
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var streakManager = StreakManager.shared
    
    var body: some View {
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
            StreakView()
                .tabItem {
                    Label("Streak", systemImage: streakManager.currentStreak >= 7 ? "flame.fill" : "flame")
                }
                .badge(streakManager.currentStreak > 0 ? "\(streakManager.currentStreak)" : nil)
                .environmentObject(themeManager)
                .environmentObject(streakManager)
            StatsView(sleepVM: sleepVM, morningVM: morningVM) // Передача в Stats
                .tabItem {
                    Label("Stats", systemImage: "chart.bar")
                }
        }
        .accentColor(Color(hex: "#FFA07A")) // Мягкий оранжевый
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#FFF8E7"), Color(hex: "#F5DEB3")]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .preferredColorScheme(themeManager.isDarkMode ? .dark : .light)
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
