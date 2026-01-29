import SwiftUI

// MARK: - Premium Soft UI & Glassmorphism 组件库

// ✅ 规范化的标签组件
struct StandardTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

// ✅ 规范化的主操作按钮 (修正版)
struct PrimaryActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(AppTheme.Colors.accent)
            .cornerRadius(AppTheme.Radius.base)
            .shadow(color: AppTheme.Colors.accent.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Premium Card Style ViewModifier
struct PremiumCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}

extension View {
    func premiumCard() -> some View {
        modifier(PremiumCardStyle())
    }
}

// MARK: - Staggered Entrance Animation
struct StaggeredEntrance: ViewModifier {
    let index: Int
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .animation(
                .spring(response: 0.55, dampingFraction: 0.82)
                .delay(Double(index) * 0.05),
                value: isVisible
            )
    }
}

extension View {
    func staggeredEntrance(index: Int, isVisible: Bool) -> some View {
        modifier(StaggeredEntrance(index: index, isVisible: isVisible))
    }
}

// MARK: - Glassmorphism Background
struct GlassmorphismBackground: ViewModifier {
    let tint: Color
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(tint.opacity(0.3))
    }
}

extension View {
    func glassmorphism(tint: Color = .white) -> some View {
        modifier(GlassmorphismBackground(tint: tint))
    }
}

// MARK: - Floating Action Button (带弥散阴影)
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    let accentColor: Color
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Capsule()
                        .fill(accentColor)
                )
                .shadow(color: accentColor.opacity(0.3), radius: 12, x: 0, y: 8)
                .shadow(color: accentColor.opacity(0.15), radius: 20, x: 0, y: 12)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Inset Input Style (CheckInView 收据风格)
struct InsetInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#F0F2F5"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
            )
    }
}

extension View {
    func insetInput() -> some View {
        modifier(InsetInputStyle())
    }
}

// MARK: - Premium Accent Gradient
struct PremiumAccentGradient: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "#FF6B6B"),
                Color(hex: "#FF5252")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Soft Neutral Colors
extension Color {
    static let softBackground = Color(hex: "#F8F9FB")
    static let softGray = Color(hex: "#F0F2F5")
    static let softText = Color(hex: "#2C3E50")
    static let softSecondary = Color(hex: "#7F8C8D")
}
