//
//  ExpandableCard.swift
//  WhatToEat
//
//  Native navigation-based dashboard card using .navigationTransition(.zoom).
//

import SwiftUI

private extension Color {
    static var profileDashboardCardSurface: Color { AppTheme.Colors.surfacePrimary }
    static var profileDashboardCardHighlightStroke: Color { AppTheme.Colors.rimLight.opacity(0.16) }
    static var profileDashboardCardStroke: Color { .black.opacity(0.04) }
    static var profileDashboardCardShadow: Color { .black.opacity(0.05) }
}

private enum ExpandableCardMotion {
    static let press = Animation.easeOut(duration: 0.12)
}

private struct DashboardCardPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.986 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.08) : ExpandableCardMotion.press, value: configuration.isPressed)
    }
}

struct ExpandableCard<Preview: View, Detail: View>: View {
    let id: String
    let cardSize: CardSize
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let detail: () -> Detail

    let namespace: Namespace.ID

    private let previewCornerRadius: CGFloat = 20

    var body: some View {
        NavigationLink {
            DashboardCardDetailPage(content: detail)
                .navigationTransition(.zoom(sourceID: transitionSourceID, in: namespace))
        } label: {
            sourceCardContainer
        }
        .buttonStyle(DashboardCardPressStyle())
        .accessibilityIdentifier("dashboard-card-\(id)")
    }

    private var transitionSourceID: String {
        "dashboard-card-\(id)"
    }

    private var sourceCardContainer: some View {
        ZStack(alignment: .topLeading) {
            cardShell(cornerRadius: previewCornerRadius)

            preview()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardSize.fixedHeight)
        .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))
        .matchedTransitionSource(id: transitionSourceID, in: namespace)
        .contentShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))
    }

    private func cardShell(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.profileDashboardCardSurface)
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.profileDashboardCardHighlightStroke, lineWidth: 0.5)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.profileDashboardCardStroke, lineWidth: 0.5)
                }
            )
            .shadow(color: Color.profileDashboardCardShadow, radius: 10, x: 0, y: 4)
    }
}

struct ZoomNavigationCard<Preview: View, Destination: View>: View {
    let id: String
    let cardSize: CardSize
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let destination: () -> Destination

    let namespace: Namespace.ID

    private let previewCornerRadius: CGFloat = 20

    var body: some View {
        NavigationLink {
            destination()
                .navigationTransition(.zoom(sourceID: transitionSourceID, in: namespace))
        } label: {
            sourceCardContainer
        }
        .buttonStyle(DashboardCardPressStyle())
        .accessibilityIdentifier("dashboard-card-\(id)")
    }

    private var transitionSourceID: String {
        "dashboard-card-\(id)"
    }

    private var sourceCardContainer: some View {
        ZStack(alignment: .topLeading) {
            cardShell(cornerRadius: previewCornerRadius)

            preview()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardSize.fixedHeight)
        .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))
        .matchedTransitionSource(id: transitionSourceID, in: namespace)
        .contentShape(RoundedRectangle(cornerRadius: previewCornerRadius, style: .continuous))
    }

    private func cardShell(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.profileDashboardCardSurface)
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.profileDashboardCardHighlightStroke, lineWidth: 0.5)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.profileDashboardCardStroke, lineWidth: 0.5)
                }
            )
            .shadow(color: Color.profileDashboardCardShadow, radius: 10, x: 0, y: 4)
    }
}

private struct DashboardCardDetailPage<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    content()
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 20)
                }
                .frame(maxWidth: 560)
                .background(cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background(AppTheme.Colors.pageBackground)
        .toolbarTitleDisplayMode(.inline)
        .environment(\.disableDashboardDetailAnimations, true)
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color.profileDashboardCardSurface)
            .overlay(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.profileDashboardCardHighlightStroke, lineWidth: 0.5)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.profileDashboardCardStroke, lineWidth: 0.5)
                }
            )
            .shadow(color: Color.profileDashboardCardShadow.opacity(0.96), radius: 16, x: 0, y: 10)
    }
}

enum CardSize {
    case small(height: CGFloat)
    case medium(height: CGFloat)
    case large(height: CGFloat)
    case auto

    var fixedHeight: CGFloat? {
        switch self {
        case .small(let height): return height
        case .medium(let height): return height
        case .large(let height): return height
        case .auto: return nil
        }
    }

    var minHeight: CGFloat {
        switch self {
        case .small: return 140
        case .medium: return 180
        case .large: return 200
        case .auto: return 120
        }
    }

    var isFixedHeight: Bool {
        switch self {
        case .small, .medium, .large: return true
        case .auto: return false
        }
    }
}
