import SwiftUI
import SwiftData

// MARK: - 决策模式
enum DecisionMode: String, CaseIterable {
    case wantToEat = "想吃什么"
    case dontWantToEat = "不想吃什么"
}

// MARK: - 决策配置
struct DecisionConfiguration {
    var mode: DecisionMode = .wantToEat
    var selectedCategories: Set<String> = []
    var selectedDistricts: Set<String> = []
    var excludedRestaurantIDs: Set<UUID> = []
}

// MARK: - 吃什么决策助手视图
struct DecisionAssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Query var restaurants: [Restaurant]
    
    // 回调闭包：传递筛选后的餐厅列表和目标餐厅ID
    var onDecisionMade: (([Restaurant], UUID?) -> Void)?
    
    @State private var configuration = DecisionConfiguration()
    @State private var currentStep: DecisionStep = .modeSelection
    @State private var selectedRestaurant: Restaurant?
    @State private var isSpinning = false
    @State private var showResult = false
    
    // 所有可用品类和地区
    private var allCategories: [String] {
        CategoryManager.shared.getAllCategories(from: restaurants)
    }
    
    private var allDistricts: [String] {
        let districts = restaurants.map { $0.district }
        return Array(Set(districts)).sorted()
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.Colors.milkWhite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 步骤指示器
                    stepIndicator
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                    
                    // 主内容区域
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            switch currentStep {
                            case .modeSelection:
                                modeSelectionView
                            case .categorySelection:
                                categorySelectionView
                            case .districtSelection:
                                districtSelectionView
                            case .spinning:
                                spinningView
                            case .result:
                                resultView
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                    
                    Spacer()
                    
                    // 底部按钮
                    bottomButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("吃什么决策助手")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
        }
    }
    
    // MARK: - 步骤指示器
    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(DecisionStep.allCases.filter { $0 != .result }, id: \.self) { step in
                Circle()
                    .fill(step.rawValue <= currentStep.rawValue ? AppTheme.Colors.darkText : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(step.rawValue == currentStep.rawValue ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: currentStep)
                
                if step != .districtSelection {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? AppTheme.Colors.darkText : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 20)
    }
    
    // MARK: - 模式选择视图
    private var modeSelectionView: some View {
        VStack(spacing: 20) {
            Text("今天想怎么选？")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("选择你的决策模式，我来帮你决定吃什么")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                ModeCard(
                    mode: .wantToEat,
                    isSelected: configuration.mode == .wantToEat,
                    icon: "checkmark.circle.fill",
                    description: "在指定范围内随机挑选"
                ) {
                    // 触觉反馈：中等强度
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    withAnimation(.spring(response: 0.3)) {
                        configuration.mode = .wantToEat
                    }
                }
                
                ModeCard(
                    mode: .dontWantToEat,
                    isSelected: configuration.mode == .dontWantToEat,
                    icon: "xmark.circle.fill",
                    description: "排除不想吃的，在剩余中挑选"
                ) {
                    // 触觉反馈：中等强度
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    
                    withAnimation(.spring(response: 0.3)) {
                        configuration.mode = .dontWantToEat
                    }
                }
            }
        }
    }
    
    // MARK: - 品类选择视图
    private var categorySelectionView: some View {
        VStack(spacing: 20) {
            Text(configuration.mode == .wantToEat ? "想吃哪种品类？" : "不想吃哪种品类？")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("可以选择多个，也可以不选")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            FlowLayout(spacing: 10) {
                ForEach(allCategories, id: \.self) { category in
                    CategoryTag(
                        name: category,
                        isSelected: configuration.selectedCategories.contains(category)
                    ) {
                        // 触觉反馈：轻微震动
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        toggleCategory(category)
                    }
                }
            }
        }
    }
    
    // MARK: - 地区选择视图
    private var districtSelectionView: some View {
        VStack(spacing: 20) {
            Text(configuration.mode == .wantToEat ? "想去哪个区域？" : "不想去哪个区域？")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            Text("可以选择多个，也可以不选")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            FlowLayout(spacing: 10) {
                ForEach(allDistricts, id: \.self) { district in
                    DistrictTag(
                        name: district,
                        isSelected: configuration.selectedDistricts.contains(district)
                    ) {
                        // 触觉反馈：轻微震动
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        
                        toggleDistrict(district)
                    }
                }
            }
        }
    }
    
    // MARK: - 转动动画视图
    private var spinningView: some View {
        VStack(spacing: 30) {
            Text("正在为你挑选...")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            ZStack {
                // 外圈
                Circle()
                    .stroke(AppTheme.Colors.darkText.opacity(0.2), lineWidth: 4)
                    .frame(width: 200, height: 200)
                
                // 转动圈
                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(AppTheme.Colors.darkText, lineWidth: 4)
                    .frame(width: 200, height: 200)
                    .rotationEffect(Angle(degrees: isSpinning ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1).repeatForever(autoreverses: false),
                        value: isSpinning
                    )
                
                // 中心图标
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.Colors.darkText)
            }
            .frame(height: 250)
            .onAppear {
                // 转动动画已移除，结果在吃啥页面展示
            }
        }
    }
    
    // MARK: - 结果视图（简化版，不再使用）
    private var resultView: some View {
        VStack(spacing: 24) {
            Text("准备完成")
                .font(.system(size: 18))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text("正在为你挑选餐厅...")
                .font(.system(size: 16))
                .foregroundColor(AppTheme.Colors.textPrimary)
        }
    }
    
    // MARK: - 底部按钮
    private var bottomButton: some View {
        Button(action: {
            // 触觉反馈：中等强度（与界面其他按钮一致）
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            nextStep()
        }) {
            HStack(spacing: 8) {
                Text(buttonText)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                
                if currentStep != .spinning && currentStep != .result {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(currentStep == .result ? Color.clear : AppTheme.Colors.darkText)
            )
            .scaleEffect(currentStep == .result ? 0.95 : 1.0)
            .animation(.spring(response: 0.2), value: currentStep)
        }
        .disabled(currentStep == .result || currentStep == .spinning)
        .opacity(currentStep == .result ? 0 : 1)
    }
    
    // MARK: - 按钮文字
    private var buttonText: String {
        switch currentStep {
        case .modeSelection:
            return "下一步"
        case .categorySelection:
            return "下一步"
        case .districtSelection:
            return "开始挑选"
        case .spinning:
            return "挑选中..."
        case .result:
            return ""
        }
    }
    
    // MARK: - 切换品类
    private func toggleCategory(_ category: String) {
        if configuration.selectedCategories.contains(category) {
            configuration.selectedCategories.remove(category)
        } else {
            configuration.selectedCategories.insert(category)
        }
    }
    
    // MARK: - 切换地区
    private func toggleDistrict(_ district: String) {
        if configuration.selectedDistricts.contains(district) {
            configuration.selectedDistricts.remove(district)
        } else {
            configuration.selectedDistricts.insert(district)
        }
    }
    
    // MARK: - 下一步
    private func nextStep() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            switch currentStep {
            case .modeSelection:
                currentStep = .categorySelection
            case .categorySelection:
                currentStep = .districtSelection
            case .districtSelection:
                // 开始挑选：获取筛选后的餐厅列表并随机选择
                let filteredRestaurants = getFilteredRestaurants()
                let targetRestaurant = filteredRestaurants.randomElement()
                
                // 调用回调闭包，传递筛选结果和目标餐厅
                onDecisionMade?(filteredRestaurants, targetRestaurant?.id)
                
                // 关闭决策助手
                dismiss()
            case .spinning, .result:
                break
            }
        }
    }
    
    // MARK: - 获取筛选后的餐厅列表
    private func getFilteredRestaurants() -> [Restaurant] {
        var filteredRestaurants = Array(restaurants)
        
        // 根据模式过滤
        switch configuration.mode {
        case .wantToEat:
            // 想吃什么模式：只保留选中的品类和地区
            if !configuration.selectedCategories.isEmpty {
                filteredRestaurants = filteredRestaurants.filter {
                    configuration.selectedCategories.contains($0.type)
                }
            }
            if !configuration.selectedDistricts.isEmpty {
                filteredRestaurants = filteredRestaurants.filter {
                    configuration.selectedDistricts.contains($0.district)
                }
            }
        case .dontWantToEat:
            // 不想吃什么模式：排除选中的品类和地区
            if !configuration.selectedCategories.isEmpty {
                filteredRestaurants = filteredRestaurants.filter {
                    !configuration.selectedCategories.contains($0.type)
                }
            }
            if !configuration.selectedDistricts.isEmpty {
                filteredRestaurants = filteredRestaurants.filter {
                    !configuration.selectedDistricts.contains($0.district)
                }
            }
        }
        
        return filteredRestaurants
    }
}

// MARK: - 决策步骤
enum DecisionStep: Int, CaseIterable {
    case modeSelection = 0
    case categorySelection = 1
    case districtSelection = 2
    case spinning = 3
    case result = 4
}

// MARK: - 模式卡片
struct ModeCard: View {
    let mode: DecisionMode
    let isSelected: Bool
    let icon: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? AppTheme.Colors.darkText : AppTheme.Colors.textSecondary)
                    .frame(width: 50)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: isSelected)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.rawValue)
                        .font(.system(size: 18, weight: isSelected ? .bold : .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.Colors.darkText)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? AppTheme.Colors.darkText.opacity(0.05) : Color.white)
                    .shadow(color: isSelected ? AppTheme.Colors.darkText.opacity(0.1) : Color.black.opacity(0.08), radius: isSelected ? 15 : 10, x: 0, y: isSelected ? 6 : 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? AppTheme.Colors.darkText.opacity(0.3) : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 品类标签
struct CategoryTag: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? AppTheme.Colors.darkText : Color.white)
                        .shadow(color: isSelected ? AppTheme.Colors.darkText.opacity(0.3) : Color.black.opacity(0.06), radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 4 : 2)
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 地区标签
struct DistrictTag: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? AppTheme.Colors.darkText : Color.white)
                        .shadow(color: isSelected ? AppTheme.Colors.darkText.opacity(0.3) : Color.black.opacity(0.06), radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 4 : 2)
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.2), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, configurations: config)
    return DecisionAssistantView()
        .modelContainer(container)
}