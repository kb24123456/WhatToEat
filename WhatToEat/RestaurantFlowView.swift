import SwiftUI
import SwiftData
import MapKit
import UIKit

// MARK: - 餐厅卡片流主视图
// 架构：列表态卡片+文本整体滑动 + 展开态Hero动画
struct RestaurantFlowView: View {
    @Query var restaurants: [Restaurant]
    @State private var viewModel = RestaurantFlowViewModel()
    @Namespace private var animationNamespace
    
    // 动画状态
    @State private var listViewOffset: CGFloat = 0
    @State private var expandedViewOffset: CGFloat = ScreenMetrics.bounds.height
    @State private var sideCardsOpacity: Double = 1.0
    @State private var sideCardsHorizontalOffset: CGFloat = 0 // 两侧卡片水平偏移
    @State private var centerCardVerticalOffset: CGFloat = 0 // 中心卡片垂直偏移
    
    // 记录上一次中心卡片ID，用于触发震动
    @State private var lastCenteredRestaurantID: Restaurant.ID?
    
    // 滚动偏移量（用于无级过渡动画）
    @State private var scrollOffset: CGFloat = 0
    
    // 随机排序后的餐厅列表
    @State private var shuffledRestaurants: [Restaurant] = []
    
    // 展开态元素动画状态
    @State private var imageOffset: CGFloat = 100
    @State private var nameOffset: CGFloat = 100
    @State private var reviewOffset: CGFloat = 100
    @State private var distanceTimeOffset: CGFloat = 100
    @State private var districtTypeOffset: CGFloat = 100
    @State private var tagsOffset: CGFloat = 100
    @State private var buttonOffset: CGFloat = 100
    
    // 展开态 ScrollView 滚动位置（用于下滑返回手势）
    @State private var expandedScrollOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    
    // 导航菜单显示状态
    @State private var showNavigationMenu = false
    @State private var selectedRestaurantForNavigation: Restaurant?
    
    // 用户偏好的地图应用（从 UserDefaults 读取）
    @AppStorage("preferredMapApp") private var preferredMapApp: String = ""
    
    // 决策助手显示状态
    @State private var showDecisionAssistant = false
    
    // 食签显示状态
    @State private var showFortune = false
    
    // 随机选择动画状态
    @State private var isRandomSelecting = false
    @State private var targetRestaurantID: Restaurant.ID?
    @State private var filteredRestaurantsForSelection: [Restaurant] = []
    @State private var excludedRestaurantIDs: Set<UUID> = []  // 已排除的餐厅ID
    @State private var showNoMoreRestaurantsAlert = false  // 显示无更多餐厅提示Alert
    
    // 展开态动画状态
    @State private var expandedViewOpacity: Double = 1.0
    
    // MARK: - 触发无更多餐厅提示
    private func triggerNoMoreRestaurantsAlert() {
        showNoMoreRestaurantsAlert = true
    }
    
    var body: some View {
        ZStack {
            DiffuseGradientBackground()
                .ignoresSafeArea()
            
            // 空数据提示
            if restaurants.isEmpty {
                emptyStateView
            } else {
                // 列表态（始终存在）
                listView
                    .offset(y: listViewOffset)
                
                // 展开态（始终存在）
                if let selected = viewModel.selectedRestaurant {
                    expandedView(restaurant: selected)
                        .offset(y: expandedViewOffset)
                }
            }
        }
        .overlay {
            // 沉浸式决策视图
            if showDecisionAssistant {
                ZStack {
                    // 背景模糊层 - 使用系统材质实现全屏模糊
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // 点击背景关闭
                            withAnimation(.easeOut(duration: 0.2)) {
                                showDecisionAssistant = false
                            }
                        }
                    
                    // 决策内容
                    ImmersiveDecisionView(onDecisionMade: { filteredRestaurants, targetID in
                        // 延迟后开始随机选择
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            // 接收决策助手的筛选结果
                            handleDecisionResult(filteredRestaurants: filteredRestaurants, targetID: targetID)
                        }
                    }, onClose: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showDecisionAssistant = false
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9)),
                        removal: .opacity.combined(with: .scale(scale: 1.1))
                    ))
                }
            }
            
            // 食签卡片视图
            if showFortune {
                ZStack {
                    // 背景模糊层
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showFortune = false
                            }
                        }
                    
                    // 食签卡片内容（新的极简INS风）
                    MinimalistFortuneCard(onClose: {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showFortune = false
                        }
                    })
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.9)),
                        removal: .opacity.combined(with: .scale(scale: 1.1))
                    ))
                }
            }
        }
        .alert("没有更多餐厅了", isPresented: $showNoMoreRestaurantsAlert) {
            Button("重新筛选", role: .none) {
                // 清空筛选状态，让用户重新选择
                resetSelectionState()
                showDecisionAssistant = true
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("当前筛选范围内的餐厅都已经看过了，是否重新筛选？")
        }
    }
    
    // MARK: - 重置选择状态
    private func resetSelectionState() {
        filteredRestaurantsForSelection = []
        excludedRestaurantIDs = []
        targetRestaurantID = nil
    }
    
    // MARK: - 处理决策结果
    private func handleDecisionResult(filteredRestaurants: [Restaurant], targetID: Restaurant.ID?) {
        guard let targetID = targetID else {
            // 没有符合条件的餐厅，显示提示
            return
        }
        
        // 保存筛选结果和目标餐厅
        filteredRestaurantsForSelection = filteredRestaurants
        targetRestaurantID = targetID
        
        // 记录已选餐厅
        excludedRestaurantIDs.insert(targetID)
        
        // 开始随机选择动画
        startRandomSelectionAnimation()
    }
    
    // MARK: - 开始随机选择动画
    private func startRandomSelectionAnimation() {
        isRandomSelecting = true
        
        // 先快速滚动到目标餐厅附近
        withAnimation(.easeInOut(duration: 1.5)) {
            viewModel.centeredRestaurantID = targetRestaurantID
        }
        
        // 动画完成后自动展开
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            isRandomSelecting = false
            
            // 找到目标餐厅并展开
            if let targetID = targetRestaurantID,
               let restaurant = restaurants.first(where: { $0.id == targetID }) {
                handleExpandAnimation(for: restaurant)
            }
        }
    }
    
    // MARK: - 重新选择餐厅（流畅丝滑版）
    private func reselectRestaurant() {
        // 获取剩余可选餐厅（排除已选过的）
        let remainingRestaurants = filteredRestaurantsForSelection.filter {
            !excludedRestaurantIDs.contains($0.id)
        }
        
        guard let newRestaurant = remainingRestaurants.randomElement() else {
            // 没有剩余餐厅，显示提示
            triggerNoMoreRestaurantsAlert()
            return
        }
        
        // 记录新选中的餐厅
        self.excludedRestaurantIDs.insert(newRestaurant.id)
        self.targetRestaurantID = newRestaurant.id
        
        // 流畅丝滑的过渡动画序列
        performSmoothReselectionTransition(to: newRestaurant)
    }
    
    // MARK: - 重新选择过渡（无放大动效）
    private func performSmoothReselectionTransition(to newRestaurant: Restaurant) {
        // 阶段1：展开态淡出
        withAnimation(.easeOut(duration: 0.2)) {
            expandedViewOpacity = 0
        }
        
        // 阶段2：卡片回到列表位置
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.25)) {
                viewModel.collapse()
                sideCardsHorizontalOffset = 0
                centerCardVerticalOffset = 0
            }
        }
        
        // 阶段3：开始快速滚动
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.isRandomSelecting = true
            
            withAnimation(.easeOut(duration: 1.0)) {
                viewModel.centeredRestaurantID = newRestaurant.id
            }
        }
        
        // 阶段4：滚动完成后展开新餐厅（使用与列表态展开相同的动画参数）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            self.isRandomSelecting = false
            
            // 使用与列表态选中展开完全相同的动画
            self.handleExpandAnimation(for: newRestaurant)
            
            // 恢复展开态透明度
            withAnimation(.easeOut(duration: 0.3)) {
                expandedViewOpacity = 1
            }
        }
    }
    
    // 当前要展开的餐厅，用于延迟展开
    @State private var pendingExpandRestaurant: Restaurant?
    
    // MARK: - 处理动画切换
    private func handleExpandAnimation(for restaurant: Restaurant) {
        // 保存待展开的餐厅
        pendingExpandRestaurant = restaurant
        
        // 先重置所有偏移量（确保元素从下方开始）
        self.resetOffsets()
        
        // 设置展开状态
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            viewModel.expand(restaurant: restaurant)
        }
        
        // 连贯动画：列表态飞出 + 展开态进入（同步进行）
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
            sideCardsHorizontalOffset = ScreenMetrics.bounds.width * 0.7 // 两侧卡片向左右飞出
            centerCardVerticalOffset = -ScreenMetrics.bounds.height // 中心卡片向上飞出
            expandedViewOffset = 0
        }
        
        // 级联动画：展开态元素从下方飞入
        // 图片（0ms）
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            self.imageOffset = 0
        }
        
        // 名称（50ms）
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.05)) {
            self.nameOffset = 0
        }
        
        // 评论（100ms）
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.1)) {
            self.reviewOffset = 0
        }
        
        // 距离/时间（150ms）
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.15)) {
            self.distanceTimeOffset = 0
        }
        
        // 区域/品类（200ms）
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.2)) {
            self.districtTypeOffset = 0
        }
        
        // 标签（250ms）
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.25)) {
            self.tagsOffset = 0
        }
        
        // 按钮（300ms）
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.3)) {
            self.buttonOffset = 0
        }
    }
    
    private func handleCollapseAnimation() {
        // 两侧卡片飞回 + 中心卡片飞回 + 展开态飞出（同步进行）
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
            self.sideCardsHorizontalOffset = 0 // 两侧卡片飞回原位
            self.centerCardVerticalOffset = 0 // 中心卡片飞回原位
            self.expandedViewOffset = ScreenMetrics.bounds.height
        }
        
        // 级联动画：展开态元素向下飞出
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            self.resetOffsets()
        }
    }
    
    private func resetOffsets() {
        imageOffset = 100
        nameOffset = 100
        reviewOffset = 100
        distanceTimeOffset = 100
        districtTypeOffset = 100
        tagsOffset = 100
        buttonOffset = 100
    }
    
    // MARK: - 空数据状态
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 80))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("还没有餐厅")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.gray)
            
            Text("点击下方 + 号添加第一家餐厅")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
        }
    }
    
    // MARK: - 列表态：卡片+文本整体
    private var listView: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            let cardWidth = min(max(screenWidth * 0.62, 228), 268)
            let cardHeight = cardWidth * 1.4
            let spacing: CGFloat = 20
            let sidePadding = max((screenWidth - cardWidth) / 2, 20)
            let topPadding: CGFloat = screenHeight * 0.10 // 减少顶部间距为决策按钮留出空间
            
            VStack(spacing: 0) {
                // 顶部按钮栏
                HStack(spacing: 12) {
                    // 决策助手按钮
                    decisionAssistantButton
                    
                    // 今日食签按钮
                    fortuneButton
                }
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(Array(shuffledRestaurants.enumerated()), id: \.element.id) { index, restaurant in
                        // 判断是否是中心卡片
                        let isCenterCard: Bool = {
                            // 如果 centeredRestaurantID 有值，比较是否匹配
                            if let centerID = viewModel.centeredRestaurantID {
                                return centerID == restaurant.id
                            }
                            // 如果 centeredRestaurantID 为 nil，默认第一个卡片为中心
                            return index == 0
                        }()
                        
                        // 判断卡片在中心左侧还是右侧
                        let isLeftSide: Bool = {
                            if let centerID = viewModel.centeredRestaurantID,
                               let centerIndex = shuffledRestaurants.firstIndex(where: { $0.id == centerID }) {
                                return index < centerIndex
                            }
                            return index < 0 // 不会执行到这里
                        }()
                        
                        // 卡片+文本整体单元
                        GeometryReader { cardGeometry in
                            // 计算卡片中心相对于屏幕中心的距离
                            let cardCenterX = cardGeometry.frame(in: .global).midX
                            let screenCenterX = geometry.size.width / 2
                            let distanceFromCenter = abs(cardCenterX - screenCenterX)
                            let distanceNormalizer = max(cardWidth * 1.08, 1)
                            let normalizedDistance = min(distanceFromCenter / distanceNormalizer, 1.0)
                            
                            VStack(spacing: 0) {
                                // 卡片图片
                                cardImage(restaurant: restaurant, width: cardWidth, height: cardHeight)
                                
                                // 文本区域 - 在下方空白处居中
                                textSection(restaurant: restaurant, isCenter: isCenterCard)
                                    .frame(height: max(0, screenHeight - cardHeight - topPadding - 140))
                            }
                            .frame(width: cardWidth)
                            .contentShape(Rectangle())
                            // 所有卡片保持不透明，只使用偏移控制动画
                            // 中心卡片：垂直偏移（向上飞出）
                            // 两侧卡片：水平偏移（向左右飞出）
                            .offset(
                                x: isCenterCard ? 0 : (isLeftSide ? -sideCardsHorizontalOffset : sideCardsHorizontalOffset),
                                y: isCenterCard ? centerCardVerticalOffset : 0
                            )
                            // 无级过渡的缩放（基于与屏幕中心的实际距离）
                            .scaleEffect(1.0 - normalizedDistance * 0.12)
                            .onTapGesture {
                                if isCenterCard {
                                    handleExpandAnimation(for: restaurant)
                                }
                            }
                        }
                        .frame(width: cardWidth)
                        .id(restaurant.id)
                    }
                }
                .padding(.horizontal, sidePadding)
                .padding(.top, topPadding) // 增加顶部间距
            }
            .scrollTargetLayout() // 标记滚动目标布局，配合 viewAligned 使用
            .scrollTargetBehavior(.viewAligned) // 中心吸附
            .scrollPosition(id: $viewModel.centeredRestaurantID, anchor: .center)
            .onAppear {
                // 每次进入视图时随机打乱餐厅顺序
                shuffledRestaurants = restaurants.shuffled()
            }
            .onChange(of: restaurants) { _, newRestaurants in
                shuffledRestaurants = newRestaurants.shuffled()
            }
            .onChange(of: viewModel.centeredRestaurantID) { _, newID in
                // 当中心卡片变化时触发轻微震动反馈
                if newID != lastCenteredRestaurantID {
                    lastCenteredRestaurantID = newID
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
            }
        }
    }
    
    // MARK: - 决策助手按钮（iOS 26 液态玻璃样式）
    private var decisionAssistantButton: some View {
        Button(action: {
            // 触觉反馈：轻微震动
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            showDecisionAssistant = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14, weight: .semibold))
                Text("帮我决定吃什么")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.glass)  // iOS 26 液态玻璃样式
        .controlSize(.regular)
    }
    
    // MARK: - 今日食签按钮（iOS 26 液态玻璃样式）
    private var fortuneButton: some View {
        Button(action: {
            // 触觉反馈：轻微震动
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            showFortune = true
        }) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                Text("今日食签")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.glass)  // iOS 26 液态玻璃样式
        .controlSize(.regular)
    }
    
    // MARK: - 列表态卡片图片
    private func cardImage(restaurant: Restaurant, width: CGFloat, height: CGFloat) -> some View {
        AsyncImageView(
            filename: restaurant.coverPhotoFilename,
            placeholder: AnyView(
                ZStack {
                    Color(hex: "#F0F0F0")
                    Image(systemName: "fork.knife")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                }
            ),
            contentMode: .fill
        )
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        // 高级边框效果 - 增强可见性
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color(hex: "#FFFFFF").opacity(0.5), lineWidth: 1.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.black.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - 计算卡片与中心的距离（用于无级过渡动画）
    private func calculateDistanceFromCenter(index: Int, centerID: Restaurant.ID?) -> CGFloat {
        guard let centerID = centerID,
              let centerIndex = shuffledRestaurants.firstIndex(where: { $0.id == centerID }) else {
            // 如果没有中心卡片，第一个卡片为中心
            return index == 0 ? 0.0 : 1.0
        }
        // 计算与中心卡片的距离，最大为1.0
        let distance = abs(CGFloat(index - centerIndex))
        return min(distance, 1.0)
    }
    
    // MARK: - 列表态文本区域
    private func textSection(restaurant: Restaurant, isCenter: Bool = false) -> some View {
        VStack(spacing: 0) {
            // 图片与名称间距：32pt（更大的呼吸空间，让图片更突出）
            Spacer().frame(height: 32)
            
            // 餐厅名称 - 中心卡片更大，两侧更小
            Text(restaurant.name)
                .font(.system(size: isCenter ? 22 : 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: isCenter ? 56 : 48) // 根据字体大小调整高度
                .fixedSize(horizontal: false, vertical: true)
            
            if !restaurant.review.isEmpty {
                // 名称与评论间距：16pt（关联间距）
                Spacer().frame(height: 16)
                
                // 评论 - 中心卡片更大，两侧更小
                Text("\"\(restaurant.review)\"")
                    .font(.system(size: isCenter ? 14 : 12, weight: .medium, design: .default))
                    .foregroundColor(.secondary)
                    .italic()
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - 展开态
    private func expandedView(restaurant: Restaurant) -> some View {
        VStack(spacing: 0) {
            // 顶部按钮栏
            HStack {
                // 返回按钮（iOS 26 液态玻璃样式）
                Button(action: {
                    handleCollapseAnimation()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        viewModel.collapse()
                    }
                }) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.glass)  // iOS 26 液态玻璃样式
                .controlSize(.mini)
                .clipShape(Circle())
                
                Spacer()
                
                // 重新选择按钮（iOS 26 液态玻璃样式）
                if !filteredRestaurantsForSelection.isEmpty {
                    Button(action: {
                        // 触觉反馈：中等强度震动
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                        
                        reselectRestaurant()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 12, weight: .semibold))
                            Text("换一家")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)  // iOS 26 液态玻璃样式
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // 可滚动内容（支持下滑返回）
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // 顶部留白，让内容视觉居中
                    Spacer().frame(height: 20)
                    
                    // 横向大图 - 从下方飞入
                    expandedImage(restaurant: restaurant)
                        .padding(.horizontal, 64) // 左右间距增加到64pt（2倍）
                        .offset(y: imageOffset)
                    
                    // 餐厅名称 - 从下方飞入
                    Text(restaurant.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(nil)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 28)
                        .offset(y: nameOffset)
                    
                    // 评论 - 从下方飞入（带指示条和双引号）
                    if !restaurant.review.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            // 左侧指示条
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(AppTheme.Colors.darkText.opacity(0.3))
                                .frame(width: 3, height: 14)
                                .padding(.top, 3)
                            
                            // 评论文本（带双引号）
                            Text("\"\(restaurant.review)\"")
                                .font(.system(size: 13, weight: .medium, design: .default))
                                .foregroundColor(.secondary)
                                .italic()
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 16)
                        .offset(y: reviewOffset)
                    }
                    
                    // 距离/时间 - 从下方飞入（第一行）
                    distanceTimeRow(restaurant: restaurant)
                        .padding(.top, 28)
                        .padding(.horizontal, 40)
                        .offset(y: distanceTimeOffset)
                    
                    // 区域/品类 - 从下方飞入（第二行）
                    districtTypeRow(restaurant: restaurant)
                        .padding(.top, 16)
                        .padding(.horizontal, 40)
                        .offset(y: districtTypeOffset)
                    
                    // 标签 - 从下方飞入
                    tagsSection(restaurant: restaurant)
                        .padding(.top, 24)
                        .padding(.horizontal, 40)
                        .offset(y: tagsOffset)
                    
                    // 按钮区域 - 去这里 + 确认选择
                    HStack(spacing: 12) {
                        // 去这里按钮
                        navigationButton(restaurant: restaurant)
                        
                        // 确认选择按钮（仅在随机选择模式下显示）
                        if !filteredRestaurantsForSelection.isEmpty {
                            confirmSelectionButton
                        }
                    }
                    .padding(.top, 40)
                    // 底部内边距：为导航条留出空间（减少间距让内容更靠近导航栏）
                    .padding(.bottom, 20)
                    .padding(.horizontal, 40)
                    .offset(y: buttonOffset)
                }
            }
            // 添加下滑返回手势
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { value in
                        // 只有在 ScrollView 位于顶部时才响应下滑手势
                        if expandedScrollOffset <= 0 && value.translation.height > 0 {
                            dragOffset = value.translation.height * 0.5
                        }
                    }
                    .onEnded { value in
                        // 只有在 ScrollView 位于顶部时才处理下滑
                        if expandedScrollOffset <= 0 && value.translation.height > 100 {
                            // 下滑超过 100pt，执行返回
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                dragOffset = 0
                                handleCollapseAnimation()
                                viewModel.collapse()
                            }
                        } else {
                            // 下滑不足，回弹
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            // 监听 ScrollView 滚动位置
            .background(
                GeometryReader { scrollGeo in
                    Color.clear
                        .onChange(of: scrollGeo.frame(in: .named("scrollView")).minY) { _, newValue in
                            expandedScrollOffset = -newValue
                        }
                }
            )
        }
        .background(AppTheme.Colors.pageBackground)
        // 添加坐标空间名称用于滚动位置计算
        .coordinateSpace(name: "scrollView")
    }
    
    // MARK: - 展开态图片 - 统一左右间距
    private func expandedImage(restaurant: Restaurant) -> some View {
        AsyncImageView(
            filename: restaurant.coverPhotoFilename,
            placeholder: AnyView(
                ZStack {
                    Color(hex: "#F0F0F0")
                    Image(systemName: "fork.knife")
                        .font(.system(size: 60))
                        .foregroundColor(Color(hex: "#CCCCCC"))
                }
            ),
            contentMode: .fill
        )
        .frame(maxWidth: .infinity)
        .aspectRatio(4 / 3, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: "#FFFFFF").opacity(0.5), lineWidth: 1.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - 距离/时间行
    private func distanceTimeRow(restaurant: Restaurant) -> some View {
        HStack(spacing: 12) {
            InfoCard(
                icon: "location.fill",
                title: "距离",
                value: distanceText(for: restaurant),
                color: AppTheme.Colors.darkText.opacity(0.6)
            )
            
            InfoCard(
                icon: "car.fill",
                title: "驾车约",
                value: driveTimeText(for: restaurant),
                color: AppTheme.Colors.secondary
            )
        }
    }
    
    // MARK: - 区域/品类行
    private func districtTypeRow(restaurant: Restaurant) -> some View {
        HStack(spacing: 12) {
            InfoCard(
                icon: "mappin.and.ellipse",
                title: "区域",
                value: restaurant.district.isEmpty ? "未知" : restaurant.district,
                color: AppTheme.Colors.accent
            )
            
            InfoCard(
                icon: "fork.knife",
                title: "品类",
                value: restaurant.type.isEmpty ? "未分类" : restaurant.type,
                color: Color.orange
            )
        }
    }
    
    // MARK: - 标签区域 - 增大尺寸
    private func tagsSection(restaurant: Restaurant) -> some View {
        FlowLayout(spacing: 10) {
            ForEach(restaurant.tags, id: \.self) { tag in
                Text(tag)
                    .font(.system(size: 13, weight: .medium)) // 从11增大到13
                    .foregroundColor(AppTheme.Colors.darkText)
                    .padding(.horizontal, 14) // 从10增大到14
                    .padding(.vertical, 7) // 从5增大到7
                    .background(
                        Capsule()
                            .fill(Color(hex: "#FFFFFF"))
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            }
        }
    }
    
    // MARK: - 导航按钮
    private func navigationButton(restaurant: Restaurant) -> some View {
        Button(action: {
            // 触觉反馈：中等强度震动
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // 首次使用：弹出选择菜单
            // 后续使用：直接打开上次选择的地图应用
            if preferredMapApp.isEmpty {
                showNavigationMenu = true
            } else {
                openPreferredMap(for: restaurant)
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 16))
                Text("去这里")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundColor(AppTheme.Colors.primaryButtonText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.primaryButtonBackground)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
        // 首次使用提示
        .alert("选择默认导航应用", isPresented: $showNavigationMenu) {
            Button("苹果地图") {
                preferredMapApp = "apple"
                openAppleMaps(for: restaurant)
            }
            Button("高德地图") {
                preferredMapApp = "gaode"
                openGaodeMap(for: restaurant)
            }
            Button("百度地图") {
                preferredMapApp = "baidu"
                openBaiduMap(for: restaurant)
            }
        } message: {
            Text("首次使用请选择默认应用，后续可通过长按重新选择")
        }
        // ContextMenu：长按弹出选择菜单（自动处理手势冲突）
        .contextMenu {
            Button("苹果地图") {
                preferredMapApp = "apple"
                openAppleMaps(for: restaurant)
            }
            
            Button("高德地图") {
                preferredMapApp = "gaode"
                openGaodeMap(for: restaurant)
            }
            
            Button("百度地图") {
                preferredMapApp = "baidu"
                openBaiduMap(for: restaurant)
            }
        } preview: {
            // 预览内容
            VStack(spacing: 8) {
                Text("选择导航应用")
                    .font(.headline)
                Text("当前默认: \(preferredMapApp.isEmpty ? "未设置" : mapAppName(for: preferredMapApp))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if preferredMapApp.isEmpty {
                    Text("首次使用请选择默认应用，后续可通过长按重新选择")
                        .font(.caption2)
                        .foregroundColor(AppTheme.Colors.darkText.opacity(0.6))
                }
            }
            .padding()
            .frame(width: 200)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - 确认选择按钮
    private var confirmSelectionButton: some View {
        Button(action: {
            // 触觉反馈：成功反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // 确认选择，清空筛选状态
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                resetSelectionState()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                Text("确认")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .foregroundColor(AppTheme.Colors.darkText)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#FFFFFF"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 获取地图应用名称
    private func mapAppName(for app: String) -> String {
        switch app {
        case "apple": return "苹果地图"
        case "gaode": return "高德地图"
        case "baidu": return "百度地图"
        default: return "未知"
        }
    }
    
    // MARK: - 打开用户偏好的地图应用
    private func openPreferredMap(for restaurant: Restaurant) {
        switch preferredMapApp {
        case "apple":
            openAppleMaps(for: restaurant)
        case "gaode":
            openGaodeMap(for: restaurant)
        case "baidu":
            openBaiduMap(for: restaurant)
        default:
            // 如果没有保存的偏好，默认打开苹果地图
            openAppleMaps(for: restaurant)
        }
    }
    
    // MARK: - 辅助方法
    private func distanceText(for restaurant: Restaurant) -> String {
        guard let userLocation = LocationManager.shared.userLocation else { return "--" }
        let distance = userLocation.distance(from: CLLocation(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        ))
        return distance < 1000 ? String(format: "%.0fm", distance) : String(format: "%.1fkm", distance / 1000)
    }
    
    private func driveTimeText(for restaurant: Restaurant) -> String {
        guard let userLocation = LocationManager.shared.userLocation else { return "--" }
        let distance = userLocation.distance(from: CLLocation(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        ))
        let timeInMinutes = Int((distance / 1000) / 30 * 60)
        if timeInMinutes < 1 { return "<1分钟" }
        else if timeInMinutes < 60 { return "\(timeInMinutes)分钟" }
        else {
            let hours = timeInMinutes / 60
            let mins = timeInMinutes % 60
            return mins > 0 ? "\(hours)小时\(mins)分" : "\(hours)小时"
        }
    }
    
    // MARK: - 打开苹果地图
    private func openAppleMaps(for restaurant: Restaurant) {
        let coordinate = CLLocationCoordinate2D(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        )
        let mapItem = MKMapItem(location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), address: nil)
        mapItem.name = restaurant.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    // MARK: - 打开高德地图
    private func openGaodeMap(for restaurant: Restaurant) {
        guard LocationManager.shared.userLocation != nil else {
            // 如果没有用户位置，直接打开高德地图
            let urlString = "iosamap://path?sourceApplication=WhatToEat&dlat=\(restaurant.latitude)&dlon=\(restaurant.longitude)&dname=\(restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&dev=0&t=0"
            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // 如果没有安装高德地图，打开 App Store
                if let appStoreURL = URL(string: "https://apps.apple.com/cn/app/高德地图/id461703208") {
                    UIApplication.shared.open(appStoreURL)
                }
            }
            return
        }
        
        // 使用用户当前位置作为起点
        let urlString = "iosamap://path?sourceApplication=WhatToEat&sid=BGVIS1&did=BGVIS2&dlat=\(restaurant.latitude)&dlon=\(restaurant.longitude)&dname=\(restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&dev=0&t=0"
        
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // 如果没有安装高德地图，打开 App Store
            if let appStoreURL = URL(string: "https://apps.apple.com/cn/app/高德地图/id461703208") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }
    
    // MARK: - 打开百度地图
    private func openBaiduMap(for restaurant: Restaurant) {
        // 将坐标转换为百度坐标系（GCJ-02 转 BD-09）
        let bdCoordinate = convertGCJ02ToBD09(lat: restaurant.latitude, lon: restaurant.longitude)
        
        guard let userLocation = LocationManager.shared.userLocation else {
            // 如果没有用户位置
            let urlString = "baidumap://map/direction?destination=latlng:\(bdCoordinate.lat),\(bdCoordinate.lon)|name:\(restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&mode=driving&coord_type=bd09ll"
            
            if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                // 如果没有安装百度地图，打开 App Store
                if let appStoreURL = URL(string: "https://apps.apple.com/cn/app/百度地图/id452186370") {
                    UIApplication.shared.open(appStoreURL)
                }
            }
            return
        }
        
        // 使用用户当前位置作为起点
        let urlString = "baidumap://map/direction?origin=latlng:\(userLocation.coordinate.latitude),\(userLocation.coordinate.longitude)|name:我的位置&destination=latlng:\(bdCoordinate.lat),\(bdCoordinate.lon)|name:\(restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&mode=driving&coord_type=gcj02"
        
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // 如果没有安装百度地图，打开 App Store
            if let appStoreURL = URL(string: "https://apps.apple.com/cn/app/百度地图/id452186370") {
                UIApplication.shared.open(appStoreURL)
            }
        }
    }
    
    // MARK: - 坐标转换（GCJ-02 转 BD-09）
    private func convertGCJ02ToBD09(lat: Double, lon: Double) -> (lat: Double, lon: Double) {
        let x = lon
        let y = lat
        let z = sqrt(x * x + y * y) + 0.00002 * sin(y * Double.pi)
        let theta = atan2(y, x) + 0.000003 * cos(x * Double.pi)
        let bdLon = z * cos(theta) + 0.0065
        let bdLat = z * sin(theta) + 0.006
        return (bdLat, bdLon)
    }
}

// MARK: - 信息卡片
struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#FFFFFF"))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
    }
}
