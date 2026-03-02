//
//  ProfileView.swift
//  WhatToEat
//
//  完全重构的 ProfileView，采用 Masonry 瀑布流布局 + Hero 展开动画
//

import SwiftUI
import SwiftData
import Charts
import PhotosUI

// MARK: - Profile View
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Restaurant.createdAt, order: .reverse) private var restaurants: [Restaurant]
    
    @State private var viewModel: ProfileViewModel
    @Namespace private var animationNamespace
    
    // 卡片尺寸定义 - 小、中、大三种固定尺寸，确保左右列高度平衡
    // 左列总高度: 140 + 200 + 180 + 160 = 680pt
    // 右列总高度: 180 + 200 + 200 + 100 = 680pt
    private let cardSizes: [String: CardSize] = [
        "stats": .small(height: 140),       // 小卡片 - 数据概览
        "consumption": .large(height: 200), // 大卡片 - 消费洞察
        "tags": .medium(height: 180),       // 中卡片 - 我的标签
        "cuisine": .medium(height: 160),    // 中卡片 - 餐饮偏好
        "categories": .medium(height: 180), // 中卡片 - 品类管理
        "restaurants": .large(height: 200), // 大卡片 - 常去餐厅
        "timeline": .large(height: 200),    // 大卡片 - 美食足迹
        "zodiac": .small(height: 100)       // 小卡片 - 味蕾星盘
    ]
    
    init() {
        _viewModel = State(initialValue: ProfileViewModel())
    }
    
    var body: some View {
        ZStack {
            // 主内容
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    // 个人资料卡片（不参与展开）
                    profileHeader
                        .padding(.horizontal, 20)
                    
                    // 两列卡片布局 - 8个卡片，左右各4个
                    // 美食足迹(timeline)放在右侧最下方
                    HStack(alignment: .top, spacing: 8) {
                        // 左列：4个卡片
                        VStack(spacing: 8) {
                            cardForId("stats")
                            cardForId("consumption")
                            cardForId("tags")
                            cardForId("cuisine")
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 右列：4个卡片 - timeline放在最下方
                        VStack(spacing: 8) {
                            cardForId("categories")
                            cardForId("restaurants")
                            cardForId("zodiac")
                            cardForId("timeline")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    // 底部空间
                    Color.clear.frame(height: 40)
                }
            }
            .background(AppTheme.Colors.pageBackground)
            
            // 展开的卡片覆盖层
            if let expandedId = viewModel.expandedCardId {
                expandedCardOverlay(id: expandedId)
                    .zIndex(100)
                    .transition(.opacity)
            }
        }
        .onAppear {
            viewModel.modelContext = modelContext
            viewModel.restaurants = restaurants
            viewModel.loadCardOrder()
        }
        .onChange(of: restaurants) { _, newRestaurants in
            viewModel.restaurants = newRestaurants
        }
    }
    
    // MARK: - Profile Header（头像穿透半透明卡片的Hero效果）
    private var profileHeader: some View {
        // 使用屏幕宽度计算，确保头像尺寸正确
        let screenWidth = UIScreen.main.bounds.width - 40  // 减去左右 padding(20)
        let avatarSize = screenWidth * 0.67  // 头像宽度 = 可用宽度的 2/3
        let cardOverlap = avatarSize * 0.2   // 卡片覆盖头像下方 1/5
        let headerHeight = avatarSize + 200  // 头部总高度（增加间距）
        
        return ZStack(alignment: .top) {
            // Layer 0: 圆角白色背景 - 覆盖整个头像和名片区域
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(Color.white)
                .frame(height: headerHeight)
                .zIndex(-1)
            
            // Layer 1: 背景层
            Color.clear
                .frame(height: headerHeight)
            
            // Layer 2: 头像层（位于卡片后方）
            // 头像顶部与白色背景顶部对齐，向下偏移以露出部分头像
            avatarLayer(size: avatarSize)
                .zIndex(0)
                .offset(y: avatarSize * 0.15)
            
            // Layer 3: 毛玻璃信息卡片层
            // 卡片顶部位置 = 头像偏移 + 头像高度 - 卡片覆盖部分
            glassInfoCard(
                avatarSize: avatarSize,
                cardOverlap: cardOverlap,
                screenWidth: screenWidth
            )
            .zIndex(1)
            .padding(.top, avatarSize * 0.15 + avatarSize - cardOverlap)
        }
        .frame(height: headerHeight)
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $viewModel.showingEditProfile) {
            EditProfileView(userProfile: $viewModel.userProfile)
        }
    }
    
    // MARK: - 头像层
    private func avatarLayer(size: CGFloat) -> some View {
        Button(action: {
            viewModel.showingEditProfile = true
        }) {
            ZStack {
                // 头像背景光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#FFB6C1").opacity(0.4),
                                Color(hex: "#FFC0CB").opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: size * 0.25,
                            endRadius: size * 0.6
                        )
                    )
                    .frame(width: size * 1.15, height: size * 1.15)
                
                // 头像主体
                Group {
                    if let avatarData = viewModel.userProfile.avatarData,
                       let uiImage = UIImage(data: avatarData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(size * 0.2)
                            .foregroundColor(Color(hex: "#FFB6C1"))
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                )
                .background(
                    Circle()
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 毛玻璃信息卡片
    private func glassInfoCard(avatarSize: CGFloat, cardOverlap: CGFloat, screenWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // 用户名 - 与卡片上边缘的间距完全由padding控制
            Text(viewModel.userProfile.nickname)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#2D3436"))
                .padding(.top, 16)
            
            // 个性签名
            Text("今天吃哪起？")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color(hex: "#B2BEC3"))
                .padding(.top, 4)
            
            // 功能按钮行（等级+称号 与 编辑按钮）- 放在进度条上方
            HStack(spacing: 16) {
                // 等级按钮（包含等级和称号）
                levelButtonWithTitle
                
                // 编辑按钮
                editButton
            }
            .padding(.top, 16)
            
            // 等级进度条
            levelProgressBar
                .padding(.horizontal, 40)
                .padding(.top, 16)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)  // 内容边距
        .background(
            // 毛玻璃材质 + 白色遮罩 + 渐变遮罩
            ZStack {
                // 基础毛玻璃
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                // 白色遮罩层 - 让卡片更白
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.01))
                
                // 顶部渐变遮罩 - 实现头像"半沉浸"效果
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.white.opacity(0.7),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .init(x: 0.5, y: 0.35)
                        )
                    )
                    .mask(
                        VStack(spacing: 0) {
                            // 顶部渐变区域 - 与卡片覆盖头像的高度一致
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.2),
                                    Color.black.opacity(0.5),
                                    Color.black
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: cardOverlap)
                            
                            // 下半部分完全不透明
                            Rectangle()
                                .fill(Color.black)
                        }
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 20, x: 0, y: 10)
        // 注意：不在卡片外部添加 padding，由 profileHeader 的调用方控制
    }
    
    // MARK: - 等级进度条
    private var levelProgressBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("等级进度")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#B2BEC3"))
                
                Spacer()
                
                Text("\(viewModel.totalCheckIns)/\(viewModel.getNextLevelRequirement())")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "#2D3436"))
            }
            
            // 圆角进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(hex: "#F1F3F4"))
                        .frame(height: 8)
                    
                    // 进度
                    let progress = min(CGFloat(viewModel.totalCheckIns) / CGFloat(viewModel.getNextLevelRequirement()), 1.0)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress, height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - 等级按钮（包含等级和称号）
    private var levelButtonWithTitle: some View {
        Button(action: {
            // 等级详情或成就页面
        }) {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(hex: "#FFD700"))
                
                Text("Lv.\(viewModel.calculateLevel())")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "#2D3436"))
                
                // 分隔线
                Rectangle()
                    .fill(Color(hex: "#FFD700").opacity(0.3))
                    .frame(width: 1, height: 12)
                
                // 等级称号
                Text(viewModel.getLevelTitle())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(hex: "#FFD700"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(hex: "#FFF8E1"))
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "#FFD700").opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 编辑按钮
    private var editButton: some View {
        Button(action: {
            viewModel.showingEditProfile = true
        }) {
            Image(systemName: "pencil")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#636E72"))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(Color(.systemGray6))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Card Factory
    @ViewBuilder
    private func cardForId(_ id: String) -> some View {
        let size = cardSizes[id] ?? .medium(height: 180)
        
        switch id {
        case "stats":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { StatsCardPreview(viewModel: viewModel) },
                detail: { StatsCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        case "consumption":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { ConsumptionCardPreview(viewModel: viewModel) },
                detail: { ConsumptionCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        case "tags":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { TagsCardPreview(viewModel: viewModel) },
                detail: { TagsCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        case "categories":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { CategoriesCardPreview(viewModel: viewModel) },
                detail: { CategoriesCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        case "cuisine":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { CuisinePreferenceCardPreview(viewModel: viewModel) },
                detail: { CuisinePreferenceCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        case "restaurants":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { RestaurantsCardPreview(viewModel: viewModel) },
                detail: { RestaurantsCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        case "timeline":
            // 美食足迹卡片 - 点击直接打开打卡记录sheet，不使用hero动画
            TimelineCardPreview(viewModel: viewModel)
                .frame(height: size.fixedHeight) // 应用固定高度
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                )
                .onTapGesture {
                    // 触觉反馈
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    viewModel.showCheckInHistory = true
                }
                .sheet(isPresented: $viewModel.showCheckInHistory) {
                    CheckInHistoryView()
                }
            
        case "zodiac":
            ExpandableCard(
                id: id,
                cardSize: size,
                preview: { ZodiacCardPreview(viewModel: viewModel) },
                detail: { ZodiacCardDetail(viewModel: viewModel) },
                isExpanded: .init(
                    get: { viewModel.expandedCardId == id },
                    set: { if $0 { viewModel.expandCard(id: id) } else { viewModel.closeExpandedCard() } }
                ),
                namespace: animationNamespace
            )
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Expanded Card Overlay
    private func expandedCardOverlay(id: String) -> some View {
        let title = cardTitle(for: id)
        
        return ExpandedCardOverlay(
            id: id,
            title: title,
            content: {
                expandedContentForId(id)
            },
            isExpanded: .init(
                get: { viewModel.expandedCardId == id },
                set: { if !$0 { viewModel.closeExpandedCard() } }
            ),
            namespace: animationNamespace
        )
    }
    
    private func cardTitle(for id: String) -> String {
        switch id {
        case "stats": return "数据概览"
        case "consumption": return "消费洞察"
        case "tags": return "我的标签"
        case "categories": return "品类管理"
        case "cuisine": return "餐饮偏好"
        case "restaurants": return "常去餐厅"
        case "timeline": return "美食足迹"
        case "zodiac": return "味蕾星盘"
        default: return ""
        }
    }
    
    @ViewBuilder
    private func expandedContentForId(_ id: String) -> some View {
        switch id {
        case "stats":
            StatsCardDetail(viewModel: viewModel)
        case "consumption":
            ConsumptionCardDetail(viewModel: viewModel)
        case "tags":
            TagsCardDetail(viewModel: viewModel)
        case "categories":
            CategoriesCardDetail(viewModel: viewModel)
        case "cuisine":
            CuisinePreferenceCardDetail(viewModel: viewModel)
        case "restaurants":
            RestaurantsCardDetail(viewModel: viewModel)
        case "timeline":
            TimelineCardDetail(viewModel: viewModel)
        case "zodiac":
            ZodiacCardDetail(viewModel: viewModel)
        default:
            EmptyView()
        }
    }
}

// MARK: - Level Badge View
struct LevelBadgeView: View {
    let level: Int
    let checkIns: Int
    
    var levelInfo: (name: String, color: Color, hasGoldRim: Bool) {
        switch level {
        case 5: return ("米其林猎手", Color.purple, true)
        case 4: return ("美食家", Color.orange, true)
        case 3: return ("资深吃货", Color.blue, false)
        case 2: return ("吃货练习生", Color.green, false)
        default: return ("美食新手", Color.gray, false)
        }
    }
    
    var body: some View {
        let info = levelInfo
        
        HStack(spacing: 4) {
            Text(info.name)
                .font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundColor(info.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(info.color.opacity(0.1))
        )
        .overlay(
            Capsule()
                .stroke(
                    info.hasGoldRim ? Color.yellow.opacity(0.6) : info.color.opacity(0.3),
                    lineWidth: info.hasGoldRim ? 1.5 : 1
                )
        )
    }
}

// MARK: - Next Level Progress View
struct NextLevelProgressView: View {
    let currentLevel: Int
    let checkIns: Int
    let nextLevelRequirement: Int
    @State private var glowOpacity: Double = 0.5

    var progress: Double {
        if currentLevel >= 5 { return 1.0 }
        let prevLevelRequirement = getPrevLevelRequirement()
        let progressInCurrentLevel = Double(checkIns - prevLevelRequirement)
        let levelRange = Double(nextLevelRequirement - prevLevelRequirement)
        return min(progressInCurrentLevel / levelRange, 1.0)
    }

    var nextLevelName: String {
        switch currentLevel {
        case 1: return "吃货练习生"
        case 2: return "资深吃货"
        case 3: return "美食家"
        case 4: return "米其林猎手"
        default: return "已满级"
        }
    }

    private func getPrevLevelRequirement() -> Int {
        switch currentLevel {
        case 1: return 0
        case 2: return 10
        case 3: return 50
        case 4: return 100
        default: return 500
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if currentLevel >= 5 {
                HStack(spacing: 2) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.yellow)
                    Text("已满级")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                }
            } else {
                Text(nextLevelName)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.mediumGray)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.babyBlue, Color.white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress, height: 4)
                            .shadow(color: AppTheme.Colors.babyBlue.opacity(glowOpacity), radius: 4, x: 0, y: 0)
                    }
                }
                .frame(width: 60, height: 4)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        glowOpacity = 0.8
                    }
                }

                Text("还需 \(nextLevelRequirement - checkIns) 次打卡")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(AppTheme.Colors.lightText)
            }
        }
        .frame(width: 80)
    }
}

// MARK: - User Profile
struct UserProfile: Codable {
    var nickname: String
    var bio: String
    var avatarData: Data?
    
    static let `default` = UserProfile(nickname: "美食探险家", bio: "今天吃什么？", avatarData: nil)
    
    static func load() -> UserProfile {
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return profile
        }
        return .default
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }
    }
}

// MARK: - Edit Profile View
struct EditProfileView: View {
    @Binding var userProfile: UserProfile
    @Environment(\.dismiss) private var dismiss
    
    @State private var nickname: String = ""
    @State private var bio: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarData: Data?
    
    var body: some View {
        NavigationView {
            Form {
                Section("头像") {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.Colors.babyBlue.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                
                                if let avatarData = avatarData,
                                   let uiImage = UIImage(data: avatarData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 96, height: 96)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(AppTheme.Colors.babyBlue)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                
                Section("基本信息") {
                    TextField("昵称", text: $nickname)
                    TextField("个性签名", text: $bio)
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        userProfile.nickname = nickname
                        userProfile.bio = bio
                        userProfile.avatarData = avatarData
                        userProfile.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                nickname = userProfile.nickname
                bio = userProfile.bio
                avatarData = userProfile.avatarData
            }
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        avatarData = data
                    }
                }
            }
        }
    }
}
