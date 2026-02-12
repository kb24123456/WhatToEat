import SwiftUI
import SwiftData
import CoreLocation

// MARK: - 动画常量
private enum FortuneAnimationConstants {
    static let springResponse: Double = 0.6
    static let springDamping: Double = 0.8
    static let flipDuration: Double = 0.6
    static let autoFlipDelay: Double = 1.5
    static let closeDuration: Double = 0.5
    static let cardWidth: CGFloat = 320
    static let cardHeight: CGFloat = 480
    static let pendantSize: CGFloat = 44
}

// MARK: - 随机选择动画常量
private enum RandomPickConstants {
    static let totalDuration: Double = 2.0            // 总时长：3秒 -> 2秒
    static let initialScrollInterval: Double = 0.02   // 更快：0.025 -> 0.02
    static let finalScrollInterval: Double = 0.12     // 更快：0.15 -> 0.12
    static let decelerationFactor: Double = 1.15
}

// MARK: - 心动匹配游戏视图 (Cover Flow + 底部卡片详情)
struct GourmetMatchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    @ObservedObject var locationManager: LocationManager = LocationManager.shared
    
    // 命名空间用于 Hero 动画
    @Namespace private var animation
    
    // 今日食签命名空间
    @Namespace private var fortuneNS
    
    // 筛选状态
    @State private var selectedDistrict: String = "全部"
    @State private var selectedType: String = "全部"
    
    // 视图状态 - 使用单一状态控制 Hero Animation
    @State private var selectedRestaurant: Restaurant? = nil
    
    // 震动反馈状态
    @State private var lastCenterIndex: Int = -1
    
    // 当前中心卡片索引
    @State private var currentCenterIndex: Int = 0
    
    // AI 文案管理器
    @StateObject private var aiManager = AICopywritingManager.shared
    
    // MARK: - 今日食签状态（转场动画版）
    @State private var isFortuneExpanded: Bool = false      // 是否展开
    @State private var showCoverCard: Bool = false          // 是否显示封面图
    @State private var showDetailCard: Bool = false         // 是否显示详情
    @State private var isFlipped: Bool = false              // 是否已翻转
    @State private var isAnimating: Bool = false            // 是否正在动画中
    @AppStorage("fortuneLastShownDate") private var lastShownDate: String = ""
    @State private var flipAngle: Double = 0                // 翻转角度
    @State private var coverScale: CGFloat = 0.1            // 封面图缩放（从挂坠大小开始）
    @State private var coverOpacity: Double = 0             // 封面图透明度
    @State private var detailOpacity: Double = 0            // 详情透明度
    
    // MARK: - 随机选择状态
    @State private var isRandomPicking: Bool = false        // 是否正在随机选择
    @State private var randomPickTimer: Timer? = nil        // 随机选择定时器
    @State private var currentRandomIndex: Int = 0          // 当前随机索引
    @State private var scrollProxy: ScrollViewProxy?        // 滚动代理
    
    // 今日是否已展示过（基于持久化的日期）
    private var hasShownToday: Bool {
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        return lastShownDate == today
    }
    
    // 高亮关键词（城市名 + 心情词/食物词）
    private var highlightKeywords: [String] {
        var keywords: [String] = []
        
        // 添加当前城市
        if let city = LocationManager.shared.currentCity {
            keywords.append(city)
            // 添加城市简称（如重庆->渝）
            if city.contains("重庆") { keywords.append("渝") }
            if city.contains("北京") { keywords.append("京") }
            if city.contains("上海") { keywords.append("沪") }
            if city.contains("广州") { keywords.append("穗") }
            if city.contains("深圳") { keywords.append("鹏") }
            if city.contains("成都") { keywords.append("蓉") }
            if city.contains("杭州") { keywords.append("杭") }
            if city.contains("南京") { keywords.append("宁") }
            if city.contains("武汉") { keywords.append("汉") }
            if city.contains("西安") { keywords.append("镐") }
        }
        
        // 常见心情词
        keywords.append(contentsOf: [
            "快乐", "开心", "幸福", "治愈", "温暖", "感动", "满足", "惬意",
            "emo", "焦虑", "疲惫", "摸鱼", "续命", "回血", "充电",
            "纠结", "选择困难", "社死", "摆烂", "躺平", "内卷"
        ])
        
        // 常见食物词
        keywords.append(contentsOf: [
            "火锅", "烧烤", "串串", "奶茶", "咖啡", "美式", "拿铁",
            "拉面", "小面", "抄手", "饺子", "汉堡", "炸鸡", "寿司",
            "披萨", "意面", "牛排", "日料", "韩餐", "川菜", "粤菜",
            "湘菜", "江浙菜", "西北菜", "东北菜", "云南菜", "泰国菜",
            "甜品", "蛋糕", "面包", "冰淇淋", "冰粉", "凉糕", "豆花",
            "螺蛳粉", "酸辣粉", "麻辣烫", "冒菜", "香锅", "干锅",
            "早茶", "下午茶", "夜宵", "早餐", "午餐", "晚餐",
            "碳水", "蛋白质", "脂肪", "热量", "卡路里"
        ])
        
        // 场景词
        keywords.append(contentsOf: [
            "工位", "办公室", "会议室", "格子间", "加班", "下班",
            "地铁", "公交", "打车", "骑车", "走路", "通勤",
            "解放碑", "洪崖洞", "江北嘴", "观音桥", "九街",
            "梯坎", "卡卡角角", "苍蝇馆子", "老字号", "网红店"
        ])
        
        return keywords
    }
    
    // 毒舌/吐槽类关键词
    private var sarcasticKeywords: [String] {
        [
            "吐槽", "毒舌", "讽刺", "讽刺", "扎心", "暴击", "伤害", "打击",
            "社死", "尴尬", "无语", "离谱", "荒谬", "荒唐", "可笑",
            "摆烂", "躺平", "内卷", "996", "007", "加班", "社畜",
            "穷", "贵", "坑", "踩雷", "翻车", "暴雷", "避雷",
            "难吃", "失望", "后悔", "上当", "被骗", "套路",
            "修仙", "续命", "摸鱼", "划水", "带薪", "偷懒",
            "饿", "馋", "馋哭", "流口水", "饿死", "饿晕",
            "胖", "减肥", "罪恶", "罪恶感", "热量炸弹",
            "纠结", "选择困难", "不知道", "随便", "都行"
        ]
    }
    
    /// 判断食签是否为毒舌/吐槽类
    private func isSarcasticFortune() -> Bool {
        guard let fortune = aiManager.todayFortune else { return false }
        let text = (fortune.analysis + fortune.yiHighlight + fortune.jiHighlight).lowercased()
        return sarcasticKeywords.contains { text.contains($0.lowercased()) }
    }
    
    // 筛选器数据
    private var districts: [String] {
        var districts = Array(Set(restaurants.map { $0.district })).sorted()
        districts.insert("全部", at: 0)
        return districts
    }
    
    private var types: [String] {
        var types = Array(Set(restaurants.map { $0.type })).sorted()
        types.insert("全部", at: 0)
        return types
    }
    
    // 筛选后的餐厅列表 - 计算属性
    private var filteredRestaurants: [Restaurant] {
        restaurants.filter { restaurant in
            let districtMatch = selectedDistrict == "全部" || restaurant.district == selectedDistrict
            let typeMatch = selectedType == "全部" || restaurant.type == selectedType
            return districtMatch && typeMatch
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            // 计算卡片尺寸和位置
            // 优化1：宽高等比例放大
            // - 上边缘位于屏幕垂直方向中线处
            // - 下边缘保持位于底部导航条上方 16pt
            let screenHeight = geometry.size.height
            let screenMidY = screenHeight / 2
            let tabBarHeight: CGFloat = 83  // 底部导航条高度（包含安全区域）
            let bottomPadding: CGFloat = 16  // 导航条上方间距
            
            let cardTopY = screenMidY  // 卡片上边缘位置：屏幕中线
            let cardBottomY = screenHeight - tabBarHeight - bottomPadding  // 卡片下边缘位置：导航条上方 16pt
            let cardHeight = cardBottomY - cardTopY
            let cardWidth = cardHeight * 0.75  // 3:4 比例
            
            ZStack {
                // 背景
                AppTheme.Colors.pageBackground
                    .ignoresSafeArea()
                
                // MARK: 顶部筛选器
                VStack {
                    filterBar
                        .padding(.top, 60)
                        .padding(.horizontal, 20)
                    
                    Spacer()
                }
                
                // MARK: Cover Flow 卡片轮播
                // 使用 frame 精确定位卡片位置和大小
                carouselArea(
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    containerWidth: geometry.size.width
                )
                .frame(
                    width: geometry.size.width,
                    height: cardHeight
                )
                .position(
                    x: geometry.size.width / 2,
                    y: cardTopY + cardHeight / 2
                )
                .blur(radius: isFortuneExpanded ? 20 : 0)
                .animation(.easeInOut(duration: 0.3), value: isFortuneExpanded)
                
                // MARK: 底部详情卡片（非全屏，带背景模糊）
                if let selectedRestaurant {
                    // 背景模糊层（对背后内容做模糊）
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                self.selectedRestaurant = nil
                            }
                        }
                        .zIndex(1)
                    
                    // 详情卡片（带立体感阴影）
                    GourmetMatchDetailCard(
                        restaurant: selectedRestaurant,
                        namespace: animation,
                        locationManager: locationManager,
                        onClose: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                self.selectedRestaurant = nil
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.8).combined(with: .opacity)
                    ))
                    .zIndex(2)
                }
                
                // MARK: 今日食签视觉交互系统（展开状态）
                fortuneInteractionSystem
                    .zIndex(3)
            }
            // MARK: - 挂坠叠加层（收起状态，不占据全屏）
            .overlay(
                fortunePendantOverlay,
                alignment: .topTrailing
            )
            // MARK: - 生命周期和状态监听
            .onAppear {
                // 加载本地缓存并获取今日食签
                Task {
                    aiManager.loadFromLocal()
                    // 获取今日食签（带缓存逻辑）
                    await aiManager.getTodayFortune()
                    
                    // 自动触发逻辑：如果是今天第一次查看，自动展开
                    await checkAndAutoExpandFortune()
                }
            }
        }
    }
    
    // MARK: - 今日食签视觉交互系统（转场动画版）
    /// 方案1：缩放展开（挂坠→封面图）
    /// 方案2：3D翻转（封面图→详情）
    private var fortuneInteractionSystem: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景遮罩（模糊效果）
                if isFortuneExpanded {
                    Color.black
                        .opacity(0.3)
                        .ignoresSafeArea()
                        .blur(radius: isFortuneExpanded ? 3 : 0)
                        .onTapGesture {
                            closeFortuneWithAnimation()
                        }
                        .transition(.opacity)
                }
                
                // 封面图卡片（可翻转）- 居中显示
                if showCoverCard {
                    fortuneCoverCard
                        .scaleEffect(coverScale)
                        .opacity(coverOpacity)
                        .rotation3DEffect(
                            .degrees(flipAngle),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.5
                        )
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        .onTapGesture {
                            if !isFlipped {
                                flipToDetail()
                            }
                        }
                }
                
                // 详情卡片（翻转后显示）- 居中显示，不应用旋转（避免镜像）
                if showDetailCard {
                    expandedFortuneCard
                        .opacity(detailOpacity)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
            }
        }
    }
    
    // MARK: - 收起状态的挂坠（作为 overlay 添加）
    var fortunePendantOverlay: some View {
        Group {
            if !isFortuneExpanded && !showCoverCard {
                minimizedFortunePendant
                    .padding(.top, 100)
                    .padding(.trailing, 20)
            }
        }
    }
    
    // MARK: - 封面图卡片（今日食签 + 星座符号）- 渐变质感版
    private var fortuneCoverCard: some View {
        ZStack {
            // 渐变背景 - 从深蓝到紫色的优雅渐变
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#1a1a2e"),
                            Color(hex: "#16213e"),
                            Color(hex: "#0f3460")
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppTheme.Colors.babyBlue.opacity(0.5),
                                    AppTheme.Colors.babyBlue.opacity(0.2)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
            
            // 装饰性光晕效果
            GeometryReader { geometry in
                Circle()
                    .fill(AppTheme.Colors.babyBlue.opacity(0.08))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .position(x: geometry.size.width * 0.8, y: geometry.size.height * 0.2)
                
                Circle()
                    .fill(Color.purple.opacity(0.06))
                    .frame(width: 150, height: 150)
                    .blur(radius: 30)
                    .position(x: geometry.size.width * 0.2, y: geometry.size.height * 0.8)
            }
            
            VStack(spacing: 24) {
                // 标题
                Text("今日食签")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: AppTheme.Colors.babyBlue.opacity(0.3), radius: 10, x: 0, y: 0)
                
                // 星座符号大图标 - 带光晕效果
                ZStack {
                    // 外发光
                    Circle()
                        .fill(AppTheme.Colors.babyBlue.opacity(0.2))
                        .frame(width: 110, height: 110)
                        .blur(radius: 8)
                    
                    // 主圆形背景
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    AppTheme.Colors.babyBlue.opacity(0.25),
                                    AppTheme.Colors.babyBlue.opacity(0.1)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 100, height: 100)
                        .overlay(
                            Circle()
                                .stroke(AppTheme.Colors.babyBlue.opacity(0.4), lineWidth: 1)
                        )
                    
                    if let zodiac = ZodiacUtil.loadZodiacSign() {
                        Text(String(zodiac.prefix(1)))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: AppTheme.Colors.babyBlue.opacity(0.5), radius: 8, x: 0, y: 0)
                    } else {
                        Text("籤")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: AppTheme.Colors.babyBlue.opacity(0.5), radius: 8, x: 0, y: 0)
                    }
                }
                
                // 提示文字
                Text("点击查看今日运势")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
            }
        }
        .frame(
            width: FortuneAnimationConstants.cardWidth,
            height: FortuneAnimationConstants.cardHeight
        )
    }
    
    // MARK: - 打开食签卡片（带动画）
    /// 非首次操作：从挂坠位置缩放展开到详情卡片
    private func openFortuneCard() {
        // 防止动画冲突
        guard !isAnimating else { return }
        isAnimating = true
        
        isFortuneExpanded = true
        
        // 判断是否为当日首次查看
        if hasShownToday {
            // 非首次：直接显示详情
            showDetailCard = true
            detailOpacity = 0.3
            
            // 执行展开动画
            withAnimation(.spring(
                response: FortuneAnimationConstants.springResponse,
                dampingFraction: FortuneAnimationConstants.springDamping
            )) {
                detailOpacity = 1.0
            }
            
            // 动画完成后重置标志
            DispatchQueue.main.asyncAfter(deadline: .now() + FortuneAnimationConstants.springResponse) {
                self.isAnimating = false
            }
        } else {
            // 首次：显示封面图 → 自动翻转
            showCoverCard = true
            
            // 方案1：缩放展开动画
            withAnimation(.spring(
                response: FortuneAnimationConstants.springResponse,
                dampingFraction: FortuneAnimationConstants.springDamping
            )) {
                coverScale = 1.0
                coverOpacity = 1.0
            }
            
            // 自动翻转（延时）
            DispatchQueue.main.asyncAfter(deadline: .now() + FortuneAnimationConstants.autoFlipDelay) {
                if !self.isFlipped {
                    self.flipToDetail()
                }
            }
        }
        
        // 标记今日已查看
        let today = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        lastShownDate = today
    }
    
    // MARK: - 3D翻转到详情
    private func flipToDetail() {
        isFlipped = true
        showDetailCard = true
        
        // 方案2：3D翻转动画
        withAnimation(.easeInOut(duration: FortuneAnimationConstants.flipDuration)) {
            flipAngle = 180
        }
        
        // 封面图淡出，详情淡入
        withAnimation(.easeInOut(duration: 0.3).delay(0.3)) {
            coverOpacity = 0
            detailOpacity = 1
        }
        
        // 完全隐藏封面图
        DispatchQueue.main.asyncAfter(deadline: .now() + FortuneAnimationConstants.flipDuration) {
            showCoverCard = false
            self.isAnimating = false
        }
    }
    
    // MARK: - 关闭食签卡片（带动画）
    private func closeFortuneWithAnimation() {
        // 防止动画冲突
        guard !isAnimating else { return }
        isAnimating = true
        
        // 如果已经翻转，先翻转回去
        if isFlipped {
            withAnimation(.easeInOut(duration: 0.4)) {
                flipAngle = 0
                detailOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                showDetailCard = false
                showCoverCard = true
                coverOpacity = 1
                
                // 缩放关闭动画
                withAnimation(.spring(
                    response: FortuneAnimationConstants.closeDuration,
                    dampingFraction: FortuneAnimationConstants.springDamping
                )) {
                    coverScale = 0.1
                    coverOpacity = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    resetFortuneState()
                }
            }
        } else {
            // 直接缩放关闭
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                coverScale = 0.1
                coverOpacity = 0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                resetFortuneState()
            }
        }
    }
    
    // MARK: - 重置状态
    private func resetFortuneState() {
        isFortuneExpanded = false
        showCoverCard = false
        showDetailCard = false
        isFlipped = false
        isAnimating = false  // 关键修复：重置动画标志
        flipAngle = 0
        coverScale = 0.1
        coverOpacity = 0
        detailOpacity = 0
    }
    
    // MARK: - 右上角挂坠
    private var minimizedFortunePendant: some View {
        Button(action: {
            openFortuneCard()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#1A1A1A"))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.babyBlue.opacity(0.3), lineWidth: 0.5)
                    )
                
                if let zodiac = ZodiacUtil.loadZodiacSign() {
                    Text(String(zodiac.prefix(1)))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    Text("籤")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                if aiManager.todayFortune != nil {
                    Circle()
                        .fill(AppTheme.Colors.xhsRed)
                        .frame(width: 8, height: 8)
                        .offset(x: 16, y: -16)
                }
            }
            .frame(width: 44, height: 44)
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
    }
    
    // MARK: - 全屏食签卡片 (深度重排版 - 解决头重脚轻)
    /// 1. 灵动排版：Light字重底色 + Bold关键词
    /// 2. 显性标签：幸运食物 / LUCKY FOOD
    /// 3. 极致脱敏：精简宜忌，缩短引导线
    /// 4. 视觉海拔：大留白，严格对齐
    /// 5. 装饰退后：纹理透明度降至0.015
    private var expandedFortuneCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let fortune = aiManager.todayFortune {
                // MARK: Header - 极简标题
                redesignedHeader(stars: fortune.fortuneStars)
                    .padding(.bottom, 24)
                
                // MARK: 主解析 - 灵动排版（Light底色 + Bold关键词）
                poeticAnalysis(fortune.analysis)
                    .padding(.bottom, 28)
                
                // MARK: 宜/忌 - 极致脱敏版
                minimalYiJiSection(
                    yi: fortune.yiHighlight,
                    yiSub: fortune.yiSub,
                    ji: fortune.jiHighlight,
                    jiSub: fortune.jiSub
                )
                .padding(.bottom, 20)
                
                // MARK: 幸运食物 - 带显性标签
                labeledFoodCard(food: fortune.luckFood)
                    .padding(.bottom, 12)
                
                // MARK: 注脚
                fadedFooter
                
            } else {
                LoadingFortuneView()
                    .padding(.vertical, 100)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .frame(width: 320, height: 480) // 固定卡片尺寸，与封面图对齐
        .background(
            redesignedContainerBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
    
    // MARK: - Redesigned Header (极简标题)
    private func redesignedHeader(stars: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("今日食签")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                HStack(spacing: 8) {
                    Text(formattedDate)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(AppTheme.Colors.lightText)
                    
                    // 星级星星（替代圆点，更易理解）
                    HStack(spacing: 2) {
                        ForEach(0..<5, id: \.self) { index in
                            Image(systemName: index < stars ? "star.fill" : "star")
                                .font(.system(size: 8))
                                .foregroundColor(index < stars ? AppTheme.Colors.babyBlue : Color.gray.opacity(0.2))
                        }
                    }
                }
            }
            
            Spacer()
            
            // 星座小图标
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.babyBlue.opacity(0.08))
                    .frame(width: 40, height: 40)
                
                if let zodiac = ZodiacUtil.loadZodiacSign() {
                    Text(String(zodiac.prefix(1)))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.Colors.babyBlue)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.Colors.babyBlue)
                }
            }
        }
    }
    
    // MARK: - Poetic Analysis (灵动排版 - 除开头外全用细字体)
    /// 仅保留开头的星座名称（如"射手座"），其余全部使用细字体
    private func poeticAnalysis(_ analysis: String) -> some View {
        // 提取前三个字（假设为星座名称，如"射手座"）
        let prefix = String(analysis.prefix(3))
        let suffix = String(analysis.dropFirst(3))
        
        return HStack(spacing: 0) {
            Text(prefix)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            +
            Text(suffix)
                .font(.system(size: 18, weight: .light, design: .rounded))
        }
        .foregroundColor(AppTheme.Colors.darkText)
        .lineSpacing(8)
        .lineLimit(5)
    }
    
    // MARK: - Minimal Yi/Ji Section (极致脱敏版)
    private func minimalYiJiSection(yi: String, yiSub: String, ji: String, jiSub: String) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // 宜 - 短引导线 + 精简文字
            HStack(alignment: .top, spacing: 12) {
                // 红色短引导线（仅对齐标题）
                Rectangle()
                    .fill(AppTheme.Colors.xhsRed)
                    .frame(width: 2, height: 20)
                    .cornerRadius(1)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("宜")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.Colors.xhsRed)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.xhsRed.opacity(0.08))
                            )
                        
                        Text(yi)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.xhsRed)
                    }
                    
                    // 说明文字 - 最多2行
                    Text(yiSub)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                        .lineLimit(2)
                        .lineSpacing(3)
                }
            }
            
            // 分隔
            Rectangle()
                .fill(Color.gray.opacity(0.06))
                .frame(height: 1)
                .padding(.leading, 14)
            
            // 忌 - 短引导线 + 精简文字
            HStack(alignment: .top, spacing: 12) {
                // 黑色短引导线
                Rectangle()
                    .fill(Color(hex: "#1A1A1A"))
                    .frame(width: 2, height: 20)
                    .cornerRadius(1)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("忌")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: "#1A1A1A"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.gray.opacity(0.08))
                            )
                        
                        Text(ji)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#1A1A1A"))
                    }
                    
                    // 说明文字 - 最多2行
                    Text(jiSub)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                        .lineLimit(2)
                        .lineSpacing(3)
                }
            }
        }
    }
    
    // MARK: - Labeled Food Card (优化版 - 减少突兀感)
    private func labeledFoodCard(food: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标签行：使用更柔和的颜色
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.7))
                
                Text("幸运食物")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(AppTheme.Colors.mediumGray)
                
                Text("/")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.Colors.lightText)
                
                Text("LUCKY FOOD")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(AppTheme.Colors.lightText)
                    .tracking(0.5)
            }
            
            // 食物名称：减小字号，使用中等字重
            Text(food)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.Colors.darkText)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.04))
        )
    }
    
    // MARK: - Footer (注脚 - 带细线装饰)
    private var fadedFooter: some View {
        HStack(spacing: 8) {
            // 左侧细线
            Rectangle()
                .fill(AppTheme.Colors.lightText.opacity(0.2))
                .frame(height: 0.5)
            
            Text("结合星盘与黄历解析")
                .font(.system(size: 9, weight: .regular))
                .foregroundColor(AppTheme.Colors.lightText)
                .opacity(0.5)
            
            // 右侧细线
            Rectangle()
                .fill(AppTheme.Colors.lightText.opacity(0.2))
                .frame(height: 0.5)
        }
        .padding(.top, 2)
    }
    
    // MARK: - Formatted Date
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: Date())
    }

    // MARK: - Redesigned Container Background (装饰退后版)
    /// 纹理透明度降至0.015，几乎不可见
    private var redesignedContainerBackground: some View {
        ZStack {
            // 98% 不透明度的 cloudWhite 背景
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "#FAFAFA").opacity(0.98))
            
            // 0.5pt 白色边缘光 (Rim Light)
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.8), lineWidth: 0.5)
            
            // 0.5pt 极其微弱的黑色外边框
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                .padding(-0.5)
            
            // 星轨几何纹理（透明度降至 0.015，几乎不可见）
            fadedAstrologicalTexture
        }
        // 更柔和的阴影
        .shadow(color: Color.black.opacity(0.02), radius: 24, x: 0, y: 16)
    }
    
    // MARK: - Faded Astrological Texture (退后处理的星轨纹理)
    /// 透明度降至0.015，仅在光线下隐约闪现
    private var fadedAstrologicalTexture: some View {
        GeometryReader { geometry in
            ZStack {
                // 外圈轨道 - 几乎不可见
                Circle()
                    .stroke(Color.gray.opacity(0.015), lineWidth: 0.5)
                    .frame(width: geometry.size.width * 0.9, height: geometry.size.width * 0.9)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.35)
                
                // 中圈轨道
                Circle()
                    .stroke(Color.gray.opacity(0.012), lineWidth: 0.5)
                    .frame(width: geometry.size.width * 0.7, height: geometry.size.width * 0.7)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.35)
                
                // 内圈轨道
                Circle()
                    .stroke(Color.gray.opacity(0.01), lineWidth: 0.5)
                    .frame(width: geometry.size.width * 0.5, height: geometry.size.width * 0.5)
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.35)
                
                // 经纬度线 - 几乎透明
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.01))
                        .frame(width: geometry.size.width * 0.3, height: 0.5)
                    Spacer()
                    Rectangle()
                        .fill(Color.gray.opacity(0.01))
                        .frame(width: geometry.size.width * 0.3, height: 0.5)
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.25)
                
                // 经纬度线 - 垂直
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.01))
                        .frame(width: 0.5, height: geometry.size.height * 0.2)
                    Spacer()
                    Rectangle()
                        .fill(Color.gray.opacity(0.02))
                        .frame(width: 0.5, height: geometry.size.height * 0.2)
                }
                .position(x: geometry.size.width * 0.3, y: geometry.size.height * 0.4)
            }
        }
    }
    
    // MARK: - Editorial Header (品牌化页眉)
    private var editorialHeader: some View {
        HStack(spacing: 12) {
            // 左侧极细水平线
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.gray.opacity(0.2)]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 40, height: 0.5)
            
            // Logo 质感标题
            HStack(spacing: 2) {
                Text("今日")
                    .font(.system(size: 16, weight: .ultraLight, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                Text("食签")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                
                // 小红书红圆点
                Circle()
                    .fill(AppTheme.Colors.xhsRed)
                    .frame(width: 6, height: 6)
                    .offset(y: -6)
            }
            .tracking(2.0)
            
            // 右侧极细水平线
            LinearGradient(
                gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.clear]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 40, height: 0.5)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Fortune Metrics (运势星级 - 奶脂圆点)
    private func fortuneMetrics(stars: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                ZStack {
                    // 激活态：呼吸发光感
                    if index < stars {
                        Circle()
                            .fill(AppTheme.Colors.babyBlue.opacity(0.2))
                            .frame(width: 14, height: 14)
                            .blur(radius: 4)
                    }
                    
                    // 奶脂圆点 (Pills)
                    Capsule()
                        .fill(index < stars ? 
                              AppTheme.Colors.babyBlue : 
                              Color(hex: "#F5F5F5"))
                        .frame(width: index < stars ? 20 : 16, height: 8)
                        .overlay(
                            Capsule()
                                .stroke(
                                    index < stars ? 
                                    Color.white.opacity(0.5) : 
                                    Color.gray.opacity(0.1),
                                    lineWidth: 0.5
                                )
                        )
                        // 未激活态：内陷感
                        .shadow(
                            color: index < stars ? Color.clear : Color.black.opacity(0.05),
                            radius: 1,
                            x: 0,
                            y: 1
                        )
                }
            }
        }
    }
    
    // MARK: - Analysis Text (主解析 - 打字机聚拢特效)
    private func analysisText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(AppTheme.Colors.darkText)
            .multilineTextAlignment(.center)
            .lineSpacing(8)
            .tracking(1.5)
    }
    
    // MARK: - Yi/Ji Section (宜/忌模块 - 非对称画报结构)
    private func yiJiSection(yi: String, yiSub: String, ji: String, jiSub: String) -> some View {
        VStack(spacing: 20) {
            // 宜 (The Red Side)
            HStack(alignment: .top, spacing: 12) {
                // 左侧 3pt 垂直色块
                Rectangle()
                    .fill(AppTheme.Colors.xhsRed)
                    .frame(width: 3, height: 50)
                    .cornerRadius(1.5)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("宜")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.xhsRed)
                        
                        Text(yi)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.xhsRed)
                    }
                    
                    Text(yiSub)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .italic()
                        .foregroundColor(AppTheme.Colors.mediumGray)
                        .lineSpacing(4)
                }
                
                Spacer()
            }
            
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.08))
                .frame(height: 1)
                .padding(.leading, 15)
            
            // 忌 (The Black Side)
            HStack(alignment: .top, spacing: 12) {
                // 左侧 3pt 垂直色块
                Rectangle()
                    .fill(Color(hex: "#1A1A1A"))
                    .frame(width: 3, height: 40)
                    .cornerRadius(1.5)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("忌")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#1A1A1A"))
                        
                        Text(ji)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "#1A1A1A"))
                    }
                    
                    Text(jiSub)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .italic()
                        .foregroundColor(AppTheme.Colors.mediumGray)
                        .lineSpacing(4)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Luck Food Capsule (转运食物 - 悬浮胶囊)
    private func luckFoodCapsule(food: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.babyBlue)
            
            Text(food)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.Colors.babyBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(AppTheme.Colors.babyBlue.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(AppTheme.Colors.babyBlue.opacity(0.2), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Signature Footer (极致注脚)
    private var signatureFooter: some View {
        VStack(spacing: 6) {
            Text("—— 结合你的星盘与今日黄历解析 ——")
                .font(.system(size: 10, weight: .thin, design: .rounded))
                .italic()
                .foregroundColor(AppTheme.Colors.lightText.opacity(0.6))
                .tracking(3.0)
            
            Text("基于您的星座与来到这个世界的日子")
                .font(.system(size: 9, weight: .thin, design: .rounded))
                .foregroundColor(AppTheme.Colors.lightText.opacity(0.4))
                .tracking(2.0)
        }
    }
    
    // MARK: - 自动触发逻辑
    /// 检查今天是否第一次查看，如果是则自动展开食签
    private func checkAndAutoExpandFortune() async {
        // 获取今天的日期字符串
        let today = getTodayDateString()
        let lastShownDate = UserDefaults.standard.string(forKey: "last_fortune_shown_date")
        
        // 如果今天还没有展示过，自动展开
        if lastShownDate != today {
            // 延迟一点时间，让用户先看到页面加载完成
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8秒
            
            await MainActor.run {
                openFortuneCard()
                
                // 记录今天已展示（通过 lastShownDate 自动更新 hasShownToday）
                print("✨ 自动展开今日食签（首次查看）")
            }
        } else {
            print("📌 今日食签已展示过，保持收起状态")
        }
    }
    
    /// 获取今天的日期字符串
    private func getTodayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // MARK: - 顶部筛选器 (与 LibraryView 同步)
    private var filterBar: some View {
        HStack(spacing: 12) {
            // 1. 地区筛选
            Menu {
                Button("全区") { selectedDistrict = "全部" }
                Divider()
                ForEach(districts.filter { $0 != "全部" }, id: \.self) { district in
                    Button(district) { selectedDistrict = district }
                }
            } label: {
                filterCapsuleLabel(
                    title: selectedDistrict == "全部" ? "地区" : selectedDistrict,
                    isSelected: selectedDistrict != "全部"
                )
            }
            
            // 2. 分类筛选
            Menu {
                Button("全部分类") { selectedType = "全部" }
                Divider()
                ForEach(types.filter { $0 != "全部" }, id: \.self) { type in
                    Button(type) { selectedType = type }
                }
            } label: {
                filterCapsuleLabel(
                    title: selectedType == "全部" ? "品类" : selectedType,
                    isSelected: selectedType != "全部"
                )
            }
            
            Spacer()
        }
    }
    
    // MARK: - 筛选胶囊标签（与 LibraryView 完全一致）
    private func filterCapsuleLabel(title: String, isSelected: Bool) -> some View {
        // 截断文本：超过4个字显示省略号
        let displayTitle = title.count > 4 ? String(title.prefix(3)) + "…" : title
        
        return HStack(spacing: 4) {
            Text(displayTitle)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                // 未选中：深黑文字 | 选中：白色文字
                .foregroundColor(isSelected ? .white : Color(hex: "#1A1A1A"))
                // 固定宽度和高度，不随内容变化
                .frame(width: 52, height: 18, alignment: .center)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 7))
                // 未选中：Baby Blue | 选中：白色
                .foregroundColor(isSelected ? .white.opacity(0.8) : AppTheme.Colors.babyBlue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                // 未选中：纯白实色 | 选中：纯黑实色
                .fill(isSelected ? Color.black : Color.white)
        )
        // 轻微阴影增加悬浮感
        .shadow(
            color: Color.black.opacity(0.08),
            radius: 6,
            x: 0,
            y: 3
        )
    }
    
    // MARK: - Cover Flow 卡片轮播区域（带随机选择功能）
    private func carouselArea(cardWidth: CGFloat, cardHeight: CGFloat, containerWidth: CGFloat) -> some View {
        Group {
            if filteredRestaurants.isEmpty {
                emptyStateView
            } else {
                let cardSpacing: CGFloat = 0
                // 内容边距：使第一个卡片居中
                let contentMargin = (containerWidth - cardWidth) / 2
                
                VStack(spacing: 16) {
                    // 骰子按钮
                    randomDiceButton
                    
                    // 卡片轮播
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: cardSpacing) {
                                ForEach(Array(filteredRestaurants.enumerated()), id: \.element.id) { index, restaurant in
                                    GourmetMatchCard(
                                        restaurant: restaurant,
                                        locationManager: locationManager,
                                        cardWidth: cardWidth,
                                        cardHeight: cardHeight
                                    )
                                    .id(index)
                                    .matchedGeometryEffect(
                                        id: restaurant.id,
                                        in: animation,
                                        isSource: selectedRestaurant?.id != restaurant.id
                                    )
                                    .frame(width: cardWidth, height: cardHeight)
                                    .visualEffect { content, proxy in
                                        let frame = proxy.frame(in: .global)
                                        let cardCenterX = frame.midX
                                        let screenCenterX = containerWidth / 2
                                        let distance = cardCenterX - screenCenterX
                                        
                                        return content
                                            .scaleEffect(scale(forDistance: abs(distance), containerWidth: containerWidth))
                                            .opacity(opacity(forDistance: abs(distance), containerWidth: containerWidth))
                                            .rotation3DEffect(
                                                .degrees(rotationAngle(forDistance: distance)),
                                                axis: (x: 0, y: 1, z: 0)
                                            )
                                    }
                                    .onTapGesture {
                                        guard selectedRestaurant == nil && !isRandomPicking else { return }
                                        
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                            selectedRestaurant = restaurant
                                        }
                                    }
                                    .onGeometryChange(for: CGRect.self) { proxy in
                                        proxy.frame(in: .global)
                                    } action: { frame in
                                        let cardCenterX = frame.midX
                                        let screenCenterX = containerWidth / 2
                                        let distance = abs(screenCenterX - cardCenterX)
                                        
                                        if distance < 10 {
                                            if currentCenterIndex != index {
                                                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                                    currentCenterIndex = index
                                                }
                                            }
                                            
                                            if lastCenterIndex != index {
                                                lastCenterIndex = index
                                                let generator = UIImpactFeedbackGenerator(style: .light)
                                                generator.impactOccurred()
                                            }
                                        }
                                    }
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .contentMargins(.horizontal, contentMargin, for: .scrollContent)
                        .onAppear {
                            scrollProxy = proxy
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 随机骰子按钮
    private var randomDiceButton: some View {
        Button(action: {
            startRandomPick()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "dice.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text("随机选择")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [AppTheme.Colors.babyBlue, AppTheme.Colors.babyBlue.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: AppTheme.Colors.babyBlue.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .disabled(isRandomPicking || filteredRestaurants.isEmpty)
        .opacity(isRandomPicking ? 0.6 : 1.0)
    }
    
    // MARK: - 开始随机选择
    private func startRandomPick() {
        guard !isRandomPicking && !filteredRestaurants.isEmpty else { return }
        
        isRandomPicking = true
        let totalRestaurants = filteredRestaurants.count
        let targetIndex = Int.random(in: 0..<totalRestaurants)
        
        // 动画参数
        var currentInterval = RandomPickConstants.initialScrollInterval
        var elapsedTime: Double = 0
        var currentIndex = currentCenterIndex
        
        // 创建定时器进行快速滚动
        randomPickTimer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { timer in
            guard let proxy = scrollProxy else {
                timer.invalidate()
                isRandomPicking = false
                return
            }
            
            // 更新索引（循环滚动）
            currentIndex = (currentIndex + 1) % totalRestaurants
            currentRandomIndex = currentIndex
            
            // 滚动到当前索引
            withAnimation(.easeInOut(duration: 0.1)) {
                proxy.scrollTo(currentIndex, anchor: .center)
            }
            
            // 震动反馈
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            // 更新时间
            elapsedTime += currentInterval
            
            // 减速逻辑
            if elapsedTime >= RandomPickConstants.totalDuration * 0.6 {
                // 逐渐减速
                currentInterval *= RandomPickConstants.decelerationFactor
                
                // 如果间隔超过最终间隔，停止并选中目标
                if currentInterval >= RandomPickConstants.finalScrollInterval {
                    timer.invalidate()
                    
                    // 最后滚动到目标索引
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        proxy.scrollTo(targetIndex, anchor: .center)
                    }
                    
                    // 延迟后自动选中
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        isRandomPicking = false
                        currentCenterIndex = targetIndex
                        
                        // 自动弹出详情
                        if targetIndex < filteredRestaurants.count {
                            let selectedRestaurant = filteredRestaurants[targetIndex]
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                self.selectedRestaurant = selectedRestaurant
                            }
                        }
                    }
                } else {
                    // 更新定时器间隔（需要重新创建定时器）
                    timer.invalidate()
                    createDeceleratingTimer(
                        interval: currentInterval,
                        elapsedTime: elapsedTime,
                        currentIndex: currentIndex,
                        targetIndex: targetIndex,
                        totalRestaurants: totalRestaurants
                    )
                }
            }
        }
    }
    
    // MARK: - 创建减速定时器
    private func createDeceleratingTimer(
        interval: Double,
        elapsedTime: Double,
        currentIndex: Int,
        targetIndex: Int,
        totalRestaurants: Int
    ) {
        var currentInterval = interval
        var elapsedTime = elapsedTime
        var currentIndex = currentIndex
        
        randomPickTimer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { timer in
            guard let proxy = scrollProxy else {
                timer.invalidate()
                isRandomPicking = false
                return
            }
            
            currentIndex = (currentIndex + 1) % totalRestaurants
            currentRandomIndex = currentIndex
            
            withAnimation(.easeInOut(duration: 0.1)) {
                proxy.scrollTo(currentIndex, anchor: .center)
            }
            
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            elapsedTime += currentInterval
            
            if elapsedTime >= RandomPickConstants.totalDuration * 0.6 {
                currentInterval *= RandomPickConstants.decelerationFactor
                
                if currentInterval >= RandomPickConstants.finalScrollInterval {
                    timer.invalidate()
                    
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                        proxy.scrollTo(targetIndex, anchor: .center)
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        isRandomPicking = false
                        currentCenterIndex = targetIndex
                        
                        if targetIndex < filteredRestaurants.count {
                            let selectedRestaurant = filteredRestaurants[targetIndex]
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                self.selectedRestaurant = selectedRestaurant
                            }
                        }
                    }
                } else {
                    timer.invalidate()
                    createDeceleratingTimer(
                        interval: currentInterval,
                        elapsedTime: elapsedTime,
                        currentIndex: currentIndex,
                        targetIndex: targetIndex,
                        totalRestaurants: totalRestaurants
                    )
                }
            }
        }
    }
    
    // MARK: - 视觉计算逻辑 (Visual Math)
    // 基于距离屏幕中心的距离计算缩放比例
    private func scale(forDistance distance: CGFloat, containerWidth: CGFloat) -> CGFloat {
        // distance: 卡片中心距离屏幕中心的距离
        // 距离为 0 时，scale = 1.0（100% 大小）
        // 距离越大，scale 越小
        let scale = 1.0 - (distance / containerWidth) * 0.25
        return max(scale, 0.75)
    }
    
    // 基于距离屏幕中心的距离计算透明度
    private func opacity(forDistance distance: CGFloat, containerWidth: CGFloat) -> Double {
        // distance: 卡片中心距离屏幕中心的距离
        // 距离为 0 时，opacity = 1.0（完全不透明）
        return Double(1.0 - (distance / 800))
    }
    
    // 基于距离屏幕中心的距离计算旋转角度
    private func rotationAngle(forDistance distance: CGFloat) -> Double {
        // distance: 卡片中心距离屏幕中心的有向距离
        // 距离为 0 时，rotation = 0°（无旋转）
        // 距离 > 0（卡片在右侧），rotation > 0（向右旋转）
        // 距离 < 0（卡片在左侧），rotation < 0（向左旋转）
        return Double(distance / 25)
    }
    
    // MARK: - 空状态
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "face.smiling")
                .font(.system(size: 64, weight: .light))
                .foregroundColor(AppTheme.Colors.babyBlue)
                .padding(.top, 40)
            
            Text("都品尝过了")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppTheme.Colors.darkText)
                .tracking(0.5)
            
            Text("换个筛选条件，继续探索美食世界")
                .font(.system(size: 14, weight: .regular))
                .italic()
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
}

// MARK: - 加载中食签视图（星轨动画视觉暗示）
struct LoadingFortuneView: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // 星轨动画
            ZStack {
                // 外圈轨道
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                    .frame(width: 80, height: 80)
                
                // 中圈轨道
                Circle()
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    .frame(width: 60, height: 60)
                
                // 内圈轨道
                Circle()
                    .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                    .frame(width: 40, height: 40)
                
                // 流动的星点（外圈）
                Circle()
                    .fill(AppTheme.Colors.babyBlue.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .offset(x: 40)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 3)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                
                // 流动的星点（中圈，反向）
                Circle()
                    .fill(AppTheme.Colors.babyBlue.opacity(0.4))
                    .frame(width: 4, height: 4)
                    .offset(x: 30)
                    .rotationEffect(.degrees(isAnimating ? -360 : 0))
                    .animation(
                        Animation.linear(duration: 2)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                
                // 中心太极卦象（简化版）
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    
                    // S曲线简化
                    Path { path in
                        path.move(to: CGPoint(x: 12, y: 4))
                        path.addCurve(
                            to: CGPoint(x: 12, y: 20),
                            control1: CGPoint(x: 20, y: 8),
                            control2: CGPoint(x: 4, y: 16)
                        )
                    }
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: 24, height: 24)
                }
                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                .animation(
                    Animation.linear(duration: 8)
                        .repeatForever(autoreverses: false),
                    value: isAnimating
                )
            }
            .frame(width: 100, height: 100)
            
            // 加载文案
            VStack(spacing: 8) {
                Text("正在连接你的星盘，翻阅今日黄历...")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.lightText)
                    .multilineTextAlignment(.center)
                
                // 动态省略号
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(AppTheme.Colors.babyBlue.opacity(0.6))
                            .frame(width: 4, height: 4)
                            .opacity(isAnimating ? 1 : 0.3)
                            .animation(
                                Animation.easeInOut(duration: 0.5)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.15),
                                value: isAnimating
                            )
                    }
                }
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onDisappear {
            isAnimating = false
        }
    }
}

// MARK: - 高亮文本组件
/// 自动检测并高亮关键词的文本视图
struct HighlightedText: View {
    let text: String
    let highlightWords: [String]
    let font: Font
    var tracking: CGFloat = 0
    var isItalic: Bool = false
    
    // 小红书红
    private let xiaohongshuRed = Color(hex: "#FF2442")
    
    var body: some View {
        // 使用计算属性构建高亮文本
        highlightedAttributedStringView
    }
    
    private var highlightedAttributedStringView: some View {
        let attributedString = buildHighlightedAttributedString()
        return Text(attributedString)
            .tracking(tracking)
            .italic(isItalic)
    }
    
    private func buildHighlightedAttributedString() -> AttributedString {
        var attributedString = AttributedString(text)
        attributedString.font = font
        attributedString.foregroundColor = AppTheme.Colors.darkText
        
        // 遍历所有关键词，高亮匹配的部分
        for word in highlightWords {
            if word.isEmpty { continue }
            
            // 查找所有匹配位置
            var searchRange = attributedString.startIndex..<attributedString.endIndex
            while let range = attributedString[searchRange].range(of: word) {
                // 应用高亮样式
                attributedString[range].foregroundColor = xiaohongshuRed
                attributedString[range].font = font.weight(.bold)
                
                // 更新搜索范围，避免死循环
                if range.upperBound >= attributedString.endIndex {
                    break
                }
                searchRange = range.upperBound..<attributedString.endIndex
            }
        }
        
        return attributedString
    }
}

// MARK: - 高亮文本组件（支持 Emoji 跳动动画）
struct HighlightedTextWithEmoji: View {
    let text: String
    let highlightWords: [String]
    let font: Font
    var tracking: CGFloat = 0
    var isItalic: Bool = false
    
    // 小红书红
    private let xiaohongshuRed = Color(hex: "#FF2442")
    
    // 检测文本末尾是否有 Emoji
    private var hasTrailingEmoji: Bool {
        guard let lastChar = text.last else { return false }
        return lastChar.isEmoji
    }
    
    // 分离文本和末尾 Emoji
    private var textWithoutEmoji: String {
        guard hasTrailingEmoji else { return text }
        return String(text.dropLast())
    }
    
    private var trailingEmoji: String? {
        guard hasTrailingEmoji else { return nil }
        return String(text.last!)
    }
    
    var body: some View {
        HStack(spacing: 2) {
            // 主文本（带高亮）
            HighlightedText(
                text: textWithoutEmoji,
                highlightWords: highlightWords,
                font: font,
                tracking: tracking,
                isItalic: isItalic
            )
            
            // 末尾 Emoji（带跳动动画）
            if let emoji = trailingEmoji {
                Text(emoji)
                    .font(font)
                    .offset(y: 0)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true),
                        value: true
                    )
                    .onAppear {
                        // 触发跳动动画
                        withAnimation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                        ) {
                            // 动画通过 offset 实现
                        }
                    }
            }
        }
    }
}

// MARK: - Character 扩展：检测 Emoji
extension Character {
    var isEmoji: Bool {
        // 简单的 Emoji 检测：检查 Unicode 范围
        let scalar = unicodeScalars.first!
        return scalar.properties.isEmoji || (scalar.value >= 0x1F600 && scalar.value <= 0x1F64F) || // 表情符号
               (scalar.value >= 0x1F300 && scalar.value <= 0x1F5FF) || // 杂项符号和象形文字
               (scalar.value >= 0x1F680 && scalar.value <= 0x1F6FF) || // 交通和地图符号
               (scalar.value >= 0x2600 && scalar.value <= 0x26FF) ||   // 杂项符号
               (scalar.value >= 0x2700 && scalar.value <= 0x27BF)      // 装饰符号
    }
}

// MARK: - 餐厅卡片组件
struct GourmetMatchCard: View {
    let restaurant: Restaurant
    let locationManager: LocationManager
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    
    init(restaurant: Restaurant, locationManager: LocationManager, cardWidth: CGFloat = 300, cardHeight: CGFloat = 400) {
        self.restaurant = restaurant
        self.locationManager = locationManager
        self.cardWidth = cardWidth
        self.cardHeight = cardHeight
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 图片区域
            AsyncImageView(
                filename: restaurant.coverPhotoFilename,
                placeholder: AnyView(
                    ZStack {
                        AppTheme.Colors.babyBlue.opacity(0.1)
                        Image(systemName: "fork.knife.circle.fill")
                            .font(.system(size: cardWidth * 0.2))
                            .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.3))
                    }
                )
            )
            .scaledToFill()
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.1),
                                Color.clear,
                                Color.clear,
                                Color.black.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            
            // 底部信息浮层
            VStack(alignment: .leading, spacing: 8) {
                Text(restaurant.name)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.4), radius: 4, x: 0, y: 2)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Text(restaurant.type)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.babyBlue)
                    
                    if restaurant.averagePrice > 0 {
                        Text("¥\(Int(restaurant.averagePrice))/人")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.8))
                    }
                    
                    if let userLocation = locationManager.userLocation {
                        let distance = userLocation.distance(from: CLLocation(
                            latitude: restaurant.latitude,
                            longitude: restaurant.longitude
                        ))
                        Text(distance < 1000 ? String(format: "%.0fm", distance) : String(format: "%.1fkm", distance / 1000))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.8))
                    }
                }
                
                if !restaurant.review.isEmpty {
                    HStack(spacing: 6) {
                        Rectangle()
                            .fill(AppTheme.Colors.babyBlue)
                            .frame(width: 2, height: 12)
                        
                        Text(restaurant.review)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0),
                        Color.black.opacity(0.4),
                        Color.black.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            )
        }
        .frame(width: cardWidth, height: cardHeight)
        .shadow(color: Color.black.opacity(0.15), radius: cardWidth * 0.067, x: 0, y: cardWidth * 0.033)
    }
}

// MARK: - 底部详情卡片（Reveal 揭示动画版 - 全部淡入）
struct GourmetMatchDetailCard: View {
    let restaurant: Restaurant
    var namespace: Namespace.ID
    let locationManager: LocationManager
    let onClose: () -> Void
    
    @State private var showNavigationMenu = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var isButtonPressed = false
    
    // 动画进度状态（用于级联动画）
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. 封面图区域（Hero 动画，提前圆角）
            AsyncImageView(
                filename: restaurant.coverPhotoFilename,
                placeholder: AnyView(
                    ZStack {
                        Color.gray.opacity(0.1)
                        Image(systemName: "fork.knife")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                )
            )
            .scaledToFill()
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .matchedGeometryEffect(id: restaurant.id, in: namespace, isSource: true)
            
            // 2. 信息区域（Reveal 揭示内容 - 全部淡入动画）
            VStack(alignment: .center, spacing: 14) {
                // 餐厅名称（淡入动画）
                Text(restaurant.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .opacity(animationProgress)
                    .offset(y: 20 * (1 - animationProgress))
                
                // 人均消费（淡入动画，稍晚出现）
                if restaurant.averagePrice > 0 {
                    HStack(spacing: 6) {
                        Text("人均")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text("¥\(Int(restaurant.averagePrice))")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .opacity(max(0, (animationProgress - 0.15) / 0.85))
                    .offset(y: 15 * (1 - max(0, (animationProgress - 0.15) / 0.85)))
                }
                
                // 距离和时间（淡入动画，更晚出现）
                if let userLocation = locationManager.userLocation {
                    let distance = userLocation.distance(from: CLLocation(
                        latitude: restaurant.latitude,
                        longitude: restaurant.longitude
                    ))
                    let distanceText = distance < 1000 ? String(format: "%.0f", distance) : String(format: "%.1f", distance / 1000)
                    let unit = distance < 1000 ? "m" : "km"
                    let drivingMinutes = Int(distance / 500)
                    
                    HStack(spacing: 24) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.primary.opacity(0.6))
                            Text("\(distanceText)\(unit)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                        }
                        
                        if drivingMinutes > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "car.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary.opacity(0.6))
                                Text("\(drivingMinutes)分钟")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    .opacity(max(0, (animationProgress - 0.3) / 0.7))
                    .offset(y: 15 * (1 - max(0, (animationProgress - 0.3) / 0.7)))
                }
                
                // 点评（淡入动画，带 Baby Blue 指示条，居中对齐）
                if !restaurant.review.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Spacer(minLength: 0)
                        
                        // Baby Blue 指示条（StackedRestaurantCard 同款）
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(AppTheme.Colors.babyBlue)
                            .frame(width: 3, height: 14)
                            .padding(.top, 3)
                        
                        Text(restaurant.review)
                            .font(.system(size: 15))
                            .foregroundColor(.primary.opacity(0.8))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: 260)
                    .opacity(max(0, (animationProgress - 0.45) / 0.55))
                    .offset(y: 10 * (1 - max(0, (animationProgress - 0.45) / 0.55)))
                }
                
                Spacer(minLength: 8)
                
                // 导航按钮（淡入动画，最后出现）
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isButtonPressed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isButtonPressed = false
                        showNavigationMenu = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.turn.up.right")
                            .font(.system(size: 14, weight: .semibold))
                        Text("去这里")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(width: 160)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    .clipShape(Capsule())
                    .scaleEffect(isButtonPressed ? 0.96 : 1.0)
                }
                .opacity(max(0, (animationProgress - 0.6) / 0.4))
                .offset(y: 10 * (1 - max(0, (animationProgress - 0.6) / 0.4)))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(width: 280)
            .background(Color.white)
        }
        .frame(width: 280, height: 480)
        // 3. 容器修饰（mask + matchedGeometryEffect + 立体感阴影）
        .mask {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
        }
        // 多层阴影营造立体感
        .shadow(
            color: Color.black.opacity(0.15),
            radius: 40,
            x: 8,
            y: 20
        )
        .shadow(
            color: Color.white.opacity(0.8),
            radius: 20,
            x: -4,
            y: -4
        )
        // 下滑手势
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height * 0.5
                    }
                }
                .onEnded { value in
                    isDragging = false
                    if value.translation.height > 100 {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            dragOffset = 500
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            onClose()
                            dragOffset = 0
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            // 触发级联淡入动画
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                animationProgress = 1.0
            }
        }
        .onDisappear {
            animationProgress = 0.0
        }
        .confirmationDialog("选择导航应用", isPresented: $showNavigationMenu, titleVisibility: .visible) {
            Button("高德地图") {
                NavigationManager.shared.openMap(type: .amap, restaurant: restaurant)
            }
            Button("百度地图") {
                NavigationManager.shared.openMap(type: .baidu, restaurant: restaurant)
            }
            Button("苹果地图") {
                NavigationManager.shared.openMap(type: .apple, restaurant: restaurant)
            }
            Button("取消", role: .cancel) { }
        }
    }
}

// MARK: - FlowLayout 辅助视图 (GourmetMatch 专用)
struct GourmetMatchFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}

// MARK: - 预览
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, configurations: config)
    
    return GourmetMatchView()
        .modelContainer(container)
}
