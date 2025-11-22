
import SwiftUI
import UserNotifications
import AVFoundation
import Speech
import WebKit
import CoreMotion
import Combine

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


final class RoosterGuardian: NSObject, WKNavigationDelegate, WKUIDelegate {
    
    private var coop: FlockController
    private var alarmStreak = 0
    private let maxAlarmRings = 70
    private var lastQuietNest: URL?
    
    init(watching coop: FlockController) {
        self.coop = coop
        super.init()
    }
    
    // Обход SSL-сигнализации
    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    // Открытие новых гнёзд (popup)
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        
        guard action.targetFrame == nil else { return nil }
        
        let newNest = NestForge.summonBirdNest(with: configuration)
        configureNestAppearance(newNest)
        raiseNestInCoop(newNest)
        
        coop.flyingNests.append(newNest)
        
        let wingSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleWingSwipe))
        wingSwipe.edges = .left
        newNest.addGestureRecognizer(wingSwipe)
        
        if isValidEgg(action.request) {
            newNest.load(action.request)
        }
        
        return newNest
    }
    
    @objc private func handleWingSwipe(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended,
              let nest = gesture.view as? WKWebView else { return }
        
        if nest.canGoBack {
            nest.goBack()
        } else if coop.flyingNests.last === nest {
            coop.calmTheFlock(returnTo: nil)
        }
    }
    
    // Тишина в курятнике (блокировка зума и жестов)
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let silenceSpell = """
        (function() {
            const vp = document.createElement('meta');
            vp.name = 'viewport';
            vp.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            document.head.appendChild(vp);
            
            const rules = document.createElement('style');
            rules.textContent = 'body { touch-action: pan-x pan-y; } input, textarea { font-size: 16px !important; }';
            document.head.appendChild(rules);
            
            document.addEventListener('gesturestart', e => e.preventDefault());
            document.addEventListener('gesturechange', e => e.preventDefault());
        })();
        """
        
        webView.evaluateJavaScript(silenceSpell) { _, error in
            if let error = error { print("Silence spell failed: \(error)") }
        }
    }
    
    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    // Защита от бесконечного кукарекания (редиректы)
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        alarmStreak += 1
        
        if alarmStreak > maxAlarmRings {
            webView.stopLoading()
            if let safe = lastQuietNest {
                webView.load(URLRequest(url: safe))
            }
            return
        }
        
        lastQuietNest = webView.url
        saveBirdFeed(from: webView)
    }
    
    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        if (error as NSError).code == NSURLErrorHTTPTooManyRedirects,
           let fallback = lastQuietNest {
            webView.load(URLRequest(url: fallback))
        }
    }
    
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            lastQuietNest = url
            
            if !(url.scheme?.hasPrefix("http") ?? false) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
            return
        }
        decisionHandler(.allow)
    }
    
    private func configureNestAppearance(_ nest: WKWebView) {
        nest
            .disableAutoConstraints()
            .allowPecking()
            .lockWings(min: 1.0, max: 1.0)
            .noFeatherBounce()
            .enableWingNavigation()
            .assignGuardian(self)
            .placeIn(coop.mainPerch)
    }
    
    private func raiseNestInCoop(_ nest: WKWebView) {
        nest.attachToPerchEdges(coop.mainPerch)
    }
    
    private func isValidEgg(_ request: URLRequest) -> Bool {
        guard let urlStr = request.url?.absoluteString,
              !urlStr.isEmpty,
              urlStr != "about:blank" else { return false }
        return true
    }
    
    private func saveBirdFeed(from webView: WKWebView) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            var feedBySack: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            
            for cookie in cookies {
                var sack = feedBySack[cookie.domain] ?? [:]
                if let props = cookie.properties {
                    sack[cookie.name] = props
                }
                feedBySack[cookie.domain] = sack
            }
            
            UserDefaults.standard.set(feedBySack, forKey: "preserved_grains")
        }
    }
}

private extension WKWebView {
    func disableAutoConstraints() -> Self { translatesAutoresizingMaskIntoConstraints = false; return self }
    func allowPecking() -> Self { scrollView.isScrollEnabled = true; return self }
    func lockWings(min: CGFloat, max: CGFloat) -> Self { scrollView.minimumZoomScale = min; scrollView.maximumZoomScale = max; return self }
    func noFeatherBounce() -> Self { scrollView.bounces = false; scrollView.bouncesZoom = false; return self }
    func enableWingNavigation() -> Self { allowsBackForwardNavigationGestures = true; return self }
    func assignGuardian(_ guardian: Any) -> Self {
        navigationDelegate = guardian as? WKNavigationDelegate
        uiDelegate = guardian as? WKUIDelegate
        return self
    }
    func placeIn(_ perch: UIView) -> Self { perch.addSubview(self); return self }
    func attachToPerchEdges(_ perch: UIView, insets: UIEdgeInsets = .zero) -> Self {
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: perch.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: perch.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: perch.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: perch.bottomAnchor, constant: -insets.bottom)
        ])
        return self
    }
}

// MARK: - Кузница гнёзд
enum NestForge {
    static func summonBirdNest(with config: WKWebViewConfiguration? = nil) -> WKWebView {
        let configuration = config ?? defaultCoopRules()
        return WKWebView(frame: .zero, configuration: configuration)
    }
    
    private static func defaultCoopRules() -> WKWebViewConfiguration {
        WKWebViewConfiguration()
            .allowDawnChorus()
            .silenceAutoPlay()
            .withDawnPreferences(morningRitual())
            .withSkyRules(freeFlightRules())
    }
    
    private static func morningRitual() -> WKPreferences {
        WKPreferences()
            .enableChirping()
            .allowFlightCalls()
    }
    
    private static func freeFlightRules() -> WKWebpagePreferences {
        WKWebpagePreferences().allowSkyScript()
    }
}

private extension WKWebViewConfiguration {
    func allowDawnChorus() -> Self { allowsInlineMediaPlayback = true; return self }
    func silenceAutoPlay() -> Self { mediaTypesRequiringUserActionForPlayback = []; return self }
    func withDawnPreferences(_ prefs: WKPreferences) -> Self { preferences = prefs; return self }
    func withSkyRules(_ rules: WKWebpagePreferences) -> Self { defaultWebpagePreferences = rules; return self }
}

private extension WKPreferences {
    func enableChirping() -> Self { javaScriptEnabled = true; return self }
    func allowFlightCalls() -> Self { javaScriptCanOpenWindowsAutomatically = true; return self }
}

private extension WKWebpagePreferences {
    func allowSkyScript() -> Self { allowsContentJavaScript = true; return self }
}

final class FlockController: ObservableObject {
    @Published var mainPerch: WKWebView!
    @Published var flyingNests: [WKWebView] = []
    
    private var observers = Set<AnyCancellable>()
    
    func awakenMainBird() {
        mainPerch = NestForge.summonBirdNest()
            .configurePerch(minZoom: 1.0, maxZoom: 1.0, bounce: false)
            .enableWingNavigation()
    }
    
    func restoreMorningFeed() {
        guard let saved = UserDefaults.standard.object(forKey: "preserved_grains") as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        
        let feeder = mainPerch.configuration.websiteDataStore.httpCookieStore
        let grains = saved.values.flatMap { $0.values }.compactMap {
            HTTPCookie(properties: $0 as [HTTPCookiePropertyKey: Any])
        }
        
        grains.forEach { feeder.setCookie($0) }
    }
    
    func refreshDawn() {
        mainPerch.reload()
    }
    
    func calmTheFlock(returnTo url: URL? = nil) {
        if !flyingNests.isEmpty {
            if let topExtra = flyingNests.last {
                topExtra.removeFromSuperview()
                flyingNests.removeLast()
            }
            if let trail = url {
                mainPerch.load(URLRequest(url: trail))
            }
        } else if mainPerch.canGoBack {
            mainPerch.goBack()
        }
    }
}

private extension WKWebView {
    func configurePerch(minZoom: CGFloat, maxZoom: CGFloat, bounce: Bool) -> Self {
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.bounces = bounce
        scrollView.bouncesZoom = bounce
        return self
    }
}

// MARK: - SwiftUI Обёртка
struct DawnWebView: UIViewRepresentable {
    let wakeUpURL: URL
    
    @StateObject private var flock = FlockController()
    
    func makeCoordinator() -> RoosterGuardian {
        RoosterGuardian(watching: flock)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        flock.awakenMainBird()
        flock.mainPerch.uiDelegate = context.coordinator
        flock.mainPerch.navigationDelegate = context.coordinator
        
        flock.restoreMorningFeed()
        flock.mainPerch.load(URLRequest(url: wakeUpURL))
        
        return flock.mainPerch
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct BirdHenAlarm: View {
    @State private var currentNest = ""
    
    var body: some View {
        ZStack {
            if let url = URL(string: currentNest) {
                DawnWebView(wakeUpURL: url)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: checkMorningCall)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LoadTempUrl"))) { _ in
            checkForEarlyBird()
        }
    }
    
    private func checkMorningCall() {
        let early = UserDefaults.standard.string(forKey: "temp_url")
        let regular = UserDefaults.standard.string(forKey: "saved_trail") ?? ""
        currentNest = early ?? regular
        
        if early != nil {
            UserDefaults.standard.removeObject(forKey: "temp_url")
        }
    }
    
    private func checkForEarlyBird() {
        if let call = UserDefaults.standard.string(forKey: "temp_url"), !call.isEmpty {
            currentNest = call
            UserDefaults.standard.removeObject(forKey: "temp_url")
        }
    }
}

