import Foundation

import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    @Published var unlockedThemes: Set<String> = ["Default"]
    
    init() {
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        if let saved = UserDefaults.standard.array(forKey: "unlockedThemes") as? [String] {
            unlockedThemes = Set(saved)
        }
    }
    
    func unlockTheme(_ theme: String) {
        unlockedThemes.insert(theme)
        UserDefaults.standard.set(Array(unlockedThemes), forKey: "unlockedThemes")
    }
    
    var currentColors: ThemeColors {
        if isDarkMode {
            return ThemeColors(
                background: Color(hex: "#1A1A2E"),
                card: Color(hex: "#16213E"),
                accent: Color(hex: "#E94560"),
                text: Color(hex: "#EEEEEE"),
                golden: Color(hex: "#FFD700")
            )
        } else {
            return ThemeColors(
                background: Color(hex: "#FFF8E7"),
                card: Color(hex: "#F5DEB3"),
                accent: Color(hex: "#FFA07A"),
                text: Color(hex: "#00008B"),
                golden: Color(hex: "#FFD700")
            )
        }
    }
}

struct ThemeColors {
    let background: Color
    let card: Color
    let accent: Color
    let text: Color
    let golden: Color
}
