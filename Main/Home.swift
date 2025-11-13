
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


final class WebTrailGuardian: NSObject, WKNavigationDelegate, WKUIDelegate {
    
    private unowned let container: BroodController
    private var redirectStreak = 0
    private let maxAllowedRedirects = 70
    private var knownGoodURL: URL?
    
    init(attachedTo container: BroodController) {
        self.container = container
        super.init()
    }
    
    // SSL Pinning Bypass
    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    // Popup Window Creation
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        
        guard navigationAction.targetFrame == nil else { return nil }
        
        let childView = WebFactory.createStandardWebView(from: configuration)
            .applyStandardAppearance()
            .embed(into: container.rootContainer)
        
        container.registerAuxiliary(view: childView)
        
        let leftEdgeSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleLeftEdgeSwipe))
        leftEdgeSwipe.edges = .left
        childView.addGestureRecognizer(leftEdgeSwipe)
        
        if navigationAction.request.url?.absoluteString != "about:blank" &&
           navigationAction.request.url?.scheme?.hasPrefix("http") == true {
            childView.load(navigationAction.request)
        }
        
        return childView
    }
    
    @objc private func handleLeftEdgeSwipe(_ recognizer: UIScreenEdgePanGestureRecognizer) {
        guard recognizer.state == .ended,
              let webView = recognizer.view as? WKWebView else { return }
        
        if webView.canGoBack {
            webView.goBack()
        } else if container.auxiliaryViews.last === webView {
            container.closeAllAuxiliary(returnTo: nil)
        }
    }
    
    // Inject viewport & touch fixes after load
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        injectViewportLock(into: webView)
    }
    
    // Suppress JS alerts
    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    // Redirect loop protection
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        redirectStreak += 1
        
        if redirectStreak > maxAllowedRedirects {
            webView.stopLoading()
            if let safe = knownGoodURL {
                webView.load(URLRequest(url: safe))
            }
            return
        }
        
        knownGoodURL = webView.url
        persistCurrentCookies(from: webView)
    }
    
    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        let nsError = error as NSError
        if nsError.code == NSURLErrorHTTPTooManyRedirects,
           let fallback = knownGoodURL {
            webView.load(URLRequest(url: fallback))
        }
    }
    
    // Navigation decision
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        knownGoodURL = url
        
        if url.scheme?.hasPrefix("http") == false {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                if webView.canGoBack { webView.goBack() }
                decisionHandler(.cancel)
                return
            }
        }
        
        decisionHandler(.allow)
    }
    
    
    private func injectViewportLock(into webView: WKWebView) {
        let js = """
        (function() {
            let meta = document.querySelector('meta[name="viewport"]');
            if (!meta) {
                meta = document.createElement('meta');
                meta.name = 'viewport';
                document.head.appendChild(meta);
            }
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
            
            let style = document.createElement('style');
            style.textContent = 'body { touch-action: pan-x pan-y; }';
            document.head.appendChild(style);
        })();
        """
        webView.evaluateJavaScript(js)
    }
    
    private func persistCurrentCookies(from webView: WKWebView) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
            var grouped: [String: [String: [HTTPCookiePropertyKey: Any]]] = [:]
            
            for cookie in cookies {
                var domainGroup = grouped[cookie.domain] ?? [:]
                if let props = cookie.properties as? [HTTPCookiePropertyKey: Any] {
                    domainGroup[cookie.name] = props
                }
                grouped[cookie.domain] = domainGroup
            }
            
            UserDefaults.standard.set(grouped, forKey: "preserved_grains")
        }
    }
}

// MARK: - WebView Builder & Extensions
enum WebFactory {
    static func createStandardWebView(from config: WKWebViewConfiguration? = nil) -> WKWebView {
        let cfg = config ?? defaultConfiguration()
        return WKWebView(frame: .zero, configuration: cfg)
    }
    
    private static func defaultConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences = {
            let prefs = WKPreferences()
            prefs.javaScriptEnabled = true
            prefs.javaScriptCanOpenWindowsAutomatically = true
            return prefs
        }()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        return config
    }
}

private extension WKWebView {
    func applyStandardAppearance() -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        scrollView.isScrollEnabled = true
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        scrollView.bounces = false
        allowsBackForwardNavigationGestures = true
        return self
    }
    
    func embed(into parent: UIView) -> Self {
        parent.addSubview(self)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            topAnchor.constraint(equalTo: parent.topAnchor),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])
        return self
    }
    
    func enableBackForwardGestures() -> WKWebView {
        allowsBackForwardNavigationGestures = true
        return self
    }
}

// MARK: - Container Manager
class BroodController: ObservableObject {
    @Published var rootContainer: WKWebView!
    @Published var auxiliaryViews: [WKWebView] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    func setupPrimaryWebView() {
        rootContainer = WebFactory.createStandardWebView()
            .applyStandardAppearance()
            .enableBackForwardGestures()
    }
    
    func restoreSavedCookies() {
        guard let raw = UserDefaults.standard.object(forKey: "preserved_grains")
                as? [String: [String: [HTTPCookiePropertyKey: AnyObject]]] else { return }
        
        let store = rootContainer.configuration.websiteDataStore.httpCookieStore
        
        for domainDict in raw.values {
            for props in domainDict.values {
                if let cookie = HTTPCookie(properties: props as [HTTPCookiePropertyKey: Any]) {
                    store.setCookie(cookie)
                }
            }
        }
    }
    
    func reloadRoot() { rootContainer.reload() }
    
    func registerAuxiliary(view: WKWebView) {
        auxiliaryViews.append(view)
    }
    
    func closeAllAuxiliary(returnTo url: URL?) {
        auxiliaryViews.forEach { $0.removeFromSuperview() }
        auxiliaryViews.removeAll()
        if let url = url { rootContainer.load(URLRequest(url: url)) }
        else if rootContainer.canGoBack { rootContainer.goBack() }
    }
}

struct BroodWebDisplay: UIViewRepresentable {
    let initialURL: URL
    
    @StateObject private var controller = BroodController()
    
    func makeCoordinator() -> WebTrailGuardian {
        WebTrailGuardian(attachedTo: controller)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        controller.setupPrimaryWebView()
        controller.rootContainer.uiDelegate = context.coordinator
        controller.rootContainer.navigationDelegate = context.coordinator
        
        controller.restoreSavedCookies()
        controller.rootContainer.load(URLRequest(url: initialURL))
        
        return controller.rootContainer
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct RootFarmInterface: View {
    @State private var currentDestination: String = ""
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let url = URL(string: currentDestination) {
                BroodWebDisplay(initialURL: url)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: applyInitialRoute)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LoadTempUrl"))) { _ in
            applyTemporaryRouteIfExists()
        }
    }
    
    private func applyInitialRoute() {
        let temporary = UserDefaults.standard.string(forKey: "temp_url")
        let persistent = UserDefaults.standard.string(forKey: "saved_trail") ?? ""
        currentDestination = temporary ?? persistent
        
        if temporary != nil {
            UserDefaults.standard.removeObject(forKey: "temp_url")
        }
    }
    
    private func applyTemporaryRouteIfExists() {
        if let temp = UserDefaults.standard.string(forKey: "temp_url"), !temp.isEmpty {
            currentDestination = temp
            UserDefaults.standard.removeObject(forKey: "temp_url")
        }
    }
}

extension Notification.Name {
    static let farmEvents = Notification.Name("farm_actions")
}
