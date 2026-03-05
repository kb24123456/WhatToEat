import SwiftUI
import SwiftData

// MARK: - 沉浸式决策步骤
enum ImmersiveDecisionStep: Int, CaseIterable {
    case modeSelection = 0
    case categorySelection = 1
    case districtSelection = 2
    case ready = 3
}

private enum StepTransitionDirection {
    case forward
    case backward
}

// MARK: - 沉浸式决策视图
struct ImmersiveDecisionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query var restaurants: [Restaurant]
    
    // 回调闭包
    var onDecisionMade: (([Restaurant], UUID?) -> Void)?
    
    // 当前步骤
    @State private var currentStep: ImmersiveDecisionStep = .modeSelection
    
    // 决策配置
    @State private var mode: DecisionMode = .wantToEat
    @State private var selectedCategories: Set<String> = []
    @State private var selectedDistricts: Set<String> = []
    
    // 动画状态
    @State private var titleOffset: CGFloat = -100
    @State private var titleOpacity: Double = 0
    @State private var optionsOffset: CGFloat = 100
    @State private var optionsOpacity: Double = 0
    @State private var isTransitioning: Bool = false
    
    // 动态计算可用的品类和地区
    private var availableCategories: [String] {
        let allCategories = CategoryManager.shared.getAllCategories(from: restaurants)
        // 根据当前模式过滤
        switch mode {
        case .wantToEat:
            // 想吃什么模式：返回所有有餐厅的品类
            return allCategories.filter { category in
                restaurants.contains { $0.type == category }
            }
        case .dontWantToEat:
            // 不想吃什么模式：返回所有品类（因为要排除）
            return allCategories
        }
    }
    
    private var availableDistricts: [String] {
        var districts: [String]
        
        switch mode {
        case .wantToEat:
            // 想吃什么模式：根据已选品类进一步过滤
            if selectedCategories.isEmpty {
                // 如果没有选品类，显示所有有餐厅的区域
                districts = restaurants.map { $0.district }
            } else {
                // 如果选了品类，只显示这些品类存在的区域
                districts = restaurants
                    .filter { selectedCategories.contains($0.type) }
                    .map { $0.district }
            }
        case .dontWantToEat:
            // 不想吃什么模式：排除已选品类后，显示剩余餐厅的区域
            let filteredRestaurants = restaurants.filter {
                !selectedCategories.contains($0.type)
            }
            districts = filteredRestaurants.map { $0.district }
        }
        
        return Array(Set(districts)).sorted()
    }

    private var canGoNextFromCategory: Bool {
        !selectedCategories.isEmpty || mode == .dontWantToEat
    }
    
    var body: some View {
        ZStack {
            // 背景层：弥散渐变
            DiffuseGradientBackground()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissByBackgroundTap()
                }
            
            // 内容层
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 120)
                
                // 标题区域
                titleView
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)
                
                Spacer()
                    .frame(height: 40)
                
                // 选项区域
                optionsView
                    .offset(y: optionsOffset)
                    .opacity(optionsOpacity)
                
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            animateIn()
        }
    }
    
    // MARK: - 标题视图
    private var titleView: some View {
        Group {
            switch currentStep {
            case .modeSelection:
                Text("今天想怎么选？")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
            case .categorySelection:
                Text(mode == .wantToEat ? "想吃哪种品类？" : "不想吃哪种品类？")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
            case .districtSelection:
                Text(mode == .wantToEat ? "想去哪个区域？" : "不想去哪个区域？")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
            case .ready:
                Text("准备好了吗？")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
            }
        }
    }
    
    // MARK: - 选项视图
    @ViewBuilder
    private var optionsView: some View {
        switch currentStep {
        case .modeSelection:
            modeSelectionOptions
        case .categorySelection:
            categorySelectionOptions
        case .districtSelection:
            districtSelectionOptions
        case .ready:
            readyButton
        }
    }
    
    // MARK: - 模式选择选项
    private var modeSelectionOptions: some View {
        VStack(spacing: 16) {
            ImmersiveOptionButton(
                title: "想吃什么",
                subtitle: "在指定范围内随机挑选",
                icon: "checkmark.circle.fill",
                isSelected: mode == .wantToEat
            ) {
                selectMode(.wantToEat)
            }
            
            ImmersiveOptionButton(
                title: "不想吃什么",
                subtitle: "排除不想吃的，在剩余中挑选",
                icon: "xmark.circle.fill",
                isSelected: mode == .dontWantToEat
            ) {
                selectMode(.dontWantToEat)
            }
        }
    }
    
    // MARK: - 品类选择选项
    private var categorySelectionOptions: some View {
        VStack(spacing: 20) {
            // 提示文字
            Text("可以选择多个，也可以不选")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            // 品类胶囊 - 带果冻感动画
            FlowLayout(spacing: 12) {
                ForEach(Array(availableCategories.enumerated()), id: \.element) { index, category in
                    JellyTag(
                        name: category,
                        isSelected: selectedCategories.contains(category),
                        index: index
                    ) {
                        toggleCategory(category)
                    }
                }
            }
            
            HStack(spacing: 12) {
                ImmersiveBackButton(title: "上一步") {
                    goToPreviousStep()
                }

                ImmersiveNextButton(title: "下一步", enabled: canGoNextFromCategory) {
                    goToNextStep()
                }
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - 区域选择选项
    private var districtSelectionOptions: some View {
        VStack(spacing: 20) {
            // 提示文字
            Text("可以选择多个，也可以不选")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            // 区域胶囊 - 带果冻感动画
            FlowLayout(spacing: 12) {
                ForEach(Array(availableDistricts.enumerated()), id: \.element) { index, district in
                    JellyTag(
                        name: district,
                        isSelected: selectedDistricts.contains(district),
                        index: index
                    ) {
                        toggleDistrict(district)
                    }
                }
            }
            
            HStack(spacing: 12) {
                ImmersiveBackButton(title: "上一步") {
                    goToPreviousStep()
                }

                ImmersiveNextButton(title: "下一步") {
                    goToNextStep()
                }
            }
            .padding(.top, 20)
        }
    }
    
    // MARK: - 开始挑选按钮
    private var readyButton: some View {
        VStack(spacing: 16) {
            Text("将根据你的选择为你推荐")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            HStack(spacing: 12) {
                ImmersiveBackButton(title: "上一步") {
                    goToPreviousStep()
                }

                ImmersiveActionButton(title: "开始挑选") {
                    startSelection()
                }
            }
        }
    }
    
    // MARK: - 动画进入（120fps优化）
    private func animateIn() {
        // 标题从上方弹入 - 使用更流畅的动画参数
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            titleOffset = 0
            titleOpacity = 1
        }
        
        // 选项从下方延迟弹入
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                optionsOffset = 0
                optionsOpacity = 1
            }
        }
    }
    
    // MARK: - 步骤切换动画（120fps优化）
    private func transitionToStep(_ targetStep: ImmersiveDecisionStep, direction: StepTransitionDirection) {
        guard !isTransitioning else { return }
        isTransitioning = true
        
        // 当前内容向四周散开消失 - 更快的退出动画
        withAnimation(.easeOut(duration: 0.2)) {
            titleOffset = direction == .forward ? -40 : 40
            titleOpacity = 0
            optionsOffset = direction == .forward ? 40 : -40
            optionsOpacity = 0
        }
        
        // 延迟后显示新内容
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            currentStep = targetStep
            
            // 重置动画状态
            titleOffset = direction == .forward ? -80 : 80
            optionsOffset = direction == .forward ? 80 : -80
            
            // 新内容弹入 - 更流畅的入场
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                titleOffset = 0
                titleOpacity = 1
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    optionsOffset = 0
                    optionsOpacity = 1
                }
                isTransitioning = false
            }
        }
    }
    
    // MARK: - 选择模式
    private func selectMode(_ selectedMode: DecisionMode) {
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        mode = selectedMode
        
        // 延迟后进入下一步
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let nextStep = ImmersiveDecisionStep(rawValue: currentStep.rawValue + 1) {
                transitionToStep(nextStep, direction: .forward)
            }
        }
    }
    
    // MARK: - 切换品类
    private func toggleCategory(_ category: String) {
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
    
    // MARK: - 切换区域
    private func toggleDistrict(_ district: String) {
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        if selectedDistricts.contains(district) {
            selectedDistricts.remove(district)
        } else {
            selectedDistricts.insert(district)
        }
    }
    
    // MARK: - 进入下一步
    private func goToNextStep() {
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if let nextStep = ImmersiveDecisionStep(rawValue: currentStep.rawValue + 1) {
            transitionToStep(nextStep, direction: .forward)
        }
    }

    // MARK: - 返回上一步
    private func goToPreviousStep() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        guard let previousStep = ImmersiveDecisionStep(rawValue: currentStep.rawValue - 1) else { return }
        transitionToStep(previousStep, direction: .backward)
    }

    // MARK: - 点击空白退出
    private func dismissByBackgroundTap() {
        guard !isTransitioning else { return }

        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()

        withAnimation(.easeIn(duration: 0.22)) {
            titleOffset = -30
            titleOpacity = 0
            optionsOffset = 30
            optionsOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            dismiss()
        }
    }
    
    // MARK: - 开始挑选
    private func startSelection() {
        // 触觉反馈：成功
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // 获取筛选后的餐厅
        let filteredRestaurants = getFilteredRestaurants()
        let targetRestaurant = filteredRestaurants.randomElement()
        
        // 内容向上飞出
        withAnimation(.easeIn(duration: 0.3)) {
            titleOffset = -200
            titleOpacity = 0
            optionsOffset = 200
            optionsOpacity = 0
        }
        
        // 延迟后关闭并回调
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            onDecisionMade?(filteredRestaurants, targetRestaurant?.id)
            dismiss()
        }
    }
    
    // MARK: - 获取筛选后的餐厅
    private func getFilteredRestaurants() -> [Restaurant] {
        var filteredRestaurants = Array(restaurants)
        
        switch mode {
        case .wantToEat:
            // 想吃什么模式
            if !selectedCategories.isEmpty {
                filteredRestaurants = filteredRestaurants.filter {
                    selectedCategories.contains($0.type)
                }
            }
            if !selectedDistricts.isEmpty {
                filteredRestaurants = filteredRestaurants.filter {
                    selectedDistricts.contains($0.district)
                }
            }
        case .dontWantToEat:
            // 不想吃什么模式
            if !selectedCategories.isEmpty {
                filteredRestaurants = filteredRestaurants.filter {
                    !selectedCategories.contains($0.type)
                }
            }
            if !selectedDistricts.isEmpty {
                filteredRestaurants = filteredRestaurants.filter {
                    !selectedDistricts.contains($0.district)
                }
            }
        }
        
        return filteredRestaurants
    }
}

// MARK: - 沉浸式选项按钮
struct ImmersiveOptionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? AppTheme.Colors.darkText : AppTheme.Colors.textSecondary)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.darkText)
                    
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(hex: "#FFFFFF").opacity(0.9))
                    // 轻量级阴影+高光方案
                    .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
                    .shadow(color: Color(hex: "#FFFFFF").opacity(0.8), radius: 4, x: 0, y: -2)
            )
        }
        .buttonStyle(ImmersiveButtonStyle())
    }
}

// MARK: - 沉浸式标签
struct ImmersiveTag: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : AppTheme.Colors.darkText)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.Colors.darkText : Color(hex: "#FFFFFF").opacity(0.85))
                        // 轻量级阴影+高光方案
                        .shadow(color: isSelected ? Color.black.opacity(0.2) : Color.black.opacity(0.06), 
                                radius: isSelected ? 8 : 6, x: 0, y: isSelected ? 4 : 3)
                        .shadow(color: Color(hex: "#FFFFFF").opacity(0.9), radius: 2, x: 0, y: -1)
                )
        }
        .buttonStyle(ImmersiveButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.2), value: isSelected)
    }
}

// MARK: - 沉浸式下一步按钮
struct ImmersiveNextButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundColor(AppTheme.Colors.darkText)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#FFFFFF"))
            )
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
        .buttonStyle(ImmersiveButtonStyle())
    }
}

// MARK: - 沉浸式上一步按钮
struct ImmersiveBackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 15, weight: .semibold))

                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundColor(AppTheme.Colors.darkText)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "#FFFFFF").opacity(0.9))
            )
        }
        .buttonStyle(ImmersiveButtonStyle())
    }
}

// MARK: - 沉浸式行动按钮
struct ImmersiveActionButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(hex: "#FFFFFF"))
                        .shadow(color: .white.opacity(0.3), radius: 20, x: 0, y: 10)
                )
        }
        .buttonStyle(ImmersiveButtonStyle())
    }
}

// MARK: - 果冻感标签（灵动活泼版）
struct JellyTag: View {
    let name: String
    let isSelected: Bool
    let index: Int
    let action: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var rotation: Double = -15
    @State private var offsetY: CGFloat = 50
    
    var body: some View {
        Button(action: {
            // 触觉反馈
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // 果冻弹跳动画
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
                action()
            }
        }) {
            Text(name)
                .font(.system(size: 15, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : AppTheme.Colors.darkText)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.Colors.darkText : Color(hex: "#FFFFFF").opacity(0.85))
                        // 轻量级阴影+高光方案
                        .shadow(color: isSelected ? Color.black.opacity(0.2) : Color.black.opacity(0.06), 
                                radius: isSelected ? 8 : 6, x: 0, y: isSelected ? 4 : 3)
                        .shadow(color: Color(hex: "#FFFFFF").opacity(0.9), radius: 2, x: 0, y: -1)
                )
        }
        .buttonStyle(JellyButtonStyle())
        .scaleEffect(scale * (isSelected ? 1.08 : 1.0))
        .opacity(opacity)
        .rotationEffect(.degrees(rotation))
        .offset(y: offsetY)
        .onAppear {
            // 错开入场动画
            let delay = Double(index) * 0.05
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                // 果冻弹入动画
                withAnimation(.interpolatingSpring(stiffness: 200, damping: 12)) {
                    scale = 1.0
                    opacity = 1.0
                    rotation = 0
                    offsetY = 0
                }
            }
        }
        .onChange(of: isSelected) { _, newValue in
            // 选中时的弹跳反馈
            if newValue {
                withAnimation(.interpolatingSpring(stiffness: 400, damping: 8)) {
                    scale = 1.15
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
                        scale = 1.08
                    }
                }
            } else {
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 10)) {
                    scale = 1.0
                }
            }
        }
    }
}

// MARK: - 果冻按钮样式
struct JellyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.interpolatingSpring(stiffness: 400, damping: 15), value: configuration.isPressed)
    }
}

// MARK: - 沉浸式按钮样式
struct ImmersiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, configurations: config)
    return ImmersiveDecisionView()
        .modelContainer(container)
}
