//
//  ThemeManager.swift
//  WhatToEat
//
//  主题管理器 - 支持浅色/深色/跟随系统模式
//

import SwiftUI
import Combine

// MARK: - 主题模式
enum ThemeMode: String, CaseIterable, Identifiable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .light: return "浅色"
        case .dark: return "深色"
        case .system: return "跟随系统"
        }
    }
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "iphone"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - 主题管理器
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    private let themeKey = "appThemeMode"
    
    @Published var currentMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(currentMode.rawValue, forKey: themeKey)
        }
    }
    
    var colorScheme: ColorScheme? {
        currentMode.colorScheme
    }
    
    private init() {
        let savedMode = UserDefaults.standard.string(forKey: themeKey) ?? "system"
        self.currentMode = ThemeMode(rawValue: savedMode) ?? .system
    }
    
    func setMode(_ mode: ThemeMode) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMode = mode
        }
    }
}

// MARK: - 奶脂主题颜色
enum MilkyColors {
    // MARK: - 背景色
    static var background: Color {
        @Environment(\.colorScheme) var colorScheme
        return colorScheme == .dark ? 
            Color(hex: "#1A1F2E") : 
            Color(hex: "#F5F7FA")
    }
    
    // MARK: - 卡片背景
    static var cardBackground: Color {
        @Environment(\.colorScheme) var colorScheme
        return colorScheme == .dark ?
            Color(hex: "#2A3040").opacity(0.6) :
            Color.white.opacity(0.75)
    }
    
    // MARK: - 卡片边框
    static var cardBorder: Color {
        @Environment(\.colorScheme) var colorScheme
        return colorScheme == .dark ?
            Color.white.opacity(0.1) :
            Color.white.opacity(0.5)
    }
    
    // MARK: - 主文字
    static var primaryText: Color {
        @Environment(\.colorScheme) var colorScheme
        return colorScheme == .dark ?
            Color(hex: "#F0F0F0") :
            Color(hex: "#1A1A1A")
    }
    
    // MARK: - 次要文字
    static var secondaryText: Color {
        @Environment(\.colorScheme) var colorScheme
        return colorScheme == .dark ?
            Color(hex: "#A0A8B8") :
            Color(hex: "#666666")
    }
    
    // MARK: - 弥散光球颜色
    static var orb1: Color {
        @Environment(\.colorScheme) var colorScheme
        return colorScheme == .dark ?
            Color.purple.opacity(0.2) :
            Color.pink.opacity(0.15)
    }
    
    static var orb2: Color {
        @Environment(\.colorScheme) var colorScheme
        return colorScheme == .dark ?
            Color.blue.opacity(0.15) :
            Color.blue.opacity(0.1)
    }
    
    static var orb3: Color {
        @Environment(\.colorScheme) var colorScheme
        return colorScheme == .dark ?
            Color.indigo.opacity(0.12) :
            Color.purple.opacity(0.08)
    }
}


