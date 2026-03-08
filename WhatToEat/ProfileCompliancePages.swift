import SwiftUI

struct ComplianceSection: Identifiable {
    let id = UUID()
    let title: String
    let paragraphs: [String]
}

struct ComplianceDocumentPage<SupplementalContent: View>: View {
    let title: String
    let updatedAt: String
    let sections: [ComplianceSection]
    let footer: String?
    let supplementalContent: SupplementalContent

    init(
        title: String,
        updatedAt: String,
        sections: [ComplianceSection],
        footer: String? = nil,
        @ViewBuilder supplementalContent: () -> SupplementalContent
    ) {
        self.title = title
        self.updatedAt = updatedAt
        self.sections = sections
        self.footer = footer
        self.supplementalContent = supplementalContent()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.Colors.darkText)

                    Text("最后更新：\(updatedAt)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondary)
                }

                supplementalContent

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.darkText)

                        ForEach(Array(section.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                            Text(paragraph)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color.secondary)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(AppTheme.Colors.surfacePrimary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
                            )
                    )
                }

                if let footer {
                    Text(footer)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(AppTheme.Colors.pageBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension ComplianceDocumentPage where SupplementalContent == EmptyView {
    init(
        title: String,
        updatedAt: String,
        sections: [ComplianceSection],
        footer: String? = nil
    ) {
        self.init(
            title: title,
            updatedAt: updatedAt,
            sections: sections,
            footer: footer
        ) {
            EmptyView()
        }
    }
}

struct SupportAndContactCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("如果你在使用 WhatToEat 过程中遇到问题，或想反馈建议、合作意向，可以通过以下方式联系我。")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Link(destination: URL(string: "mailto:357831193@qq.com")!) {
                    supportContactRow(
                        icon: "envelope.fill",
                        tint: Color(hex: "#5C8DFF"),
                        title: "联系邮箱",
                        value: "357831193@qq.com"
                    )
                }
                .buttonStyle(.plain)

                Link(destination: URL(string: "https://xhslink.com/m/9qcmtV4wkKg")!) {
                    supportContactRow(
                        icon: "link.circle.fill",
                        tint: Color(hex: "#E84393"),
                        title: "小红书",
                        value: "查看作者主页"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.Colors.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.black.opacity(0.05), lineWidth: 0.8)
                )
        )
    }

    private func supportContactRow(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(tint.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.darkText)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.secondary)
        }
        .contentShape(Rectangle())
    }
}

struct DeleteAccountExplanationPage: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    @State private var showDeleteAlert = false

    let onDeleteAssociation: () -> Void

    private let sections: [ComplianceSection] = [
        ComplianceSection(
            title: "删除的是什么",
            paragraphs: [
                "删除账户仅表示移除当前设备中与 Apple ID 相关的登录关联信息，包括账户标识与已保存的显示名称。该操作不会删除你已经记录的餐厅、打卡、消费、标签、地图足迹等本地数据。"
            ]
        ),
        ComplianceSection(
            title: "删除后会发生什么",
            paragraphs: [
                "删除 Apple ID 账户关联后，当前设备将恢复为未登录状态。与账户关联的功能，例如账户切换、需要 Apple ID 的 Prime 面容 ID 验证、依赖 Apple ID 的恢复流程，将需要你重新登录后才能继续使用。",
                "本机已有的餐厅与打卡数据不会被清除；如果你之后重新登录 Apple ID，这些本地数据仍然可以继续使用。"
            ]
        ),
        ComplianceSection(
            title: "操作前说明",
            paragraphs: [
                "如果你只是想暂时停用账户功能，直接退出账户通常已经足够。",
                "如果你确认不再希望当前 Apple ID 与 WhatToEat 保持关联，可以继续执行下方的删除账户关联操作。"
            ]
        )
    ]

    var body: some View {
        ComplianceDocumentPage(
            title: "删除账户说明",
            updatedAt: "2026 年 3 月 8 日",
            sections: sections,
            footer: "本说明用于解释 App 内删除账户关联的处理范围。若 Apple 的账户体系或相关服务规则发生变化，WhatToEat 可能会同步调整该流程。"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text(authManager.isSignedIn ? "当前账户：\(authManager.displayLabel)" : "当前未登录 Apple ID")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.secondary)

                Button {
                    showDeleteAlert = true
                } label: {
                    Text(authManager.isSignedIn ? "删除 Apple ID 账户关联" : "当前无账户可删除")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(authManager.isSignedIn ? Color(hex: "#D63031") : Color.secondary.opacity(0.35))
                        )
                }
                .buttonStyle(.plain)
                .disabled(!authManager.isSignedIn)
            }
        }
        .alert("删除账户关联", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) {
                onDeleteAssociation()
                dismiss()
            }
        } message: {
            Text("删除后将退出当前 Apple ID，并关闭依赖账户状态的安全校验；本机餐厅与打卡数据会保留。")
        }
    }
}
