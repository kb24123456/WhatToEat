import SwiftUI
import SwiftData
import CoreLocation

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
    
    // MARK: - 今日食签状态
    @State private var isFortuneExpanded: Bool = false  // 默认收起态，由自动触发控制
    @State private var dragOffset: CGSize = .zero       // 拖拽偏移量
    @State private var dragScale: CGFloat = 1.0         // 拖拽缩放
    @State private var dragOpacity: Double = 1.0        // 拖拽透明度
    @State private var hasShownToday: Bool = false      // 今日是否已展示过
    
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
                
                // MARK: 底部详情卡片（非全屏）
                if let selectedRestaurant {
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }
                
                // MARK: 今日食签视觉交互系统
                fortuneInteractionSystem
                    .zIndex(3)
            }
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
    
    // MARK: - 今日食签视觉交互系统
    private var fortuneInteractionSystem: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景遮罩（仅在展开时显示）
                if isFortuneExpanded {
                    Color.black
                        .opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.interpolatingSpring(stiffness: 280, damping: 22)) {
                                isFortuneExpanded = false
                            }
                        }
                }
                
                // 根据状态显示挂坠或全屏卡片
                if isFortuneExpanded {
                    // 全屏食签卡片
                    expandedFortuneCard
                        .frame(width: geometry.size.width * 0.85)
                        .offset(dragOffset)
                        .scaleEffect(dragScale)
                        .opacity(dragOpacity)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    // 支持向任意方向的拖拽，但优先响应向右上角的拖拽
                                    dragOffset = value.translation
                                    
                                    // 根据拖拽距离计算缩放和透明度
                                    let distance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                                    let progress = min(distance / 200, 1.0) // 最大进度为1
                                    
                                    // 等比例缩小：从 1.0 到 0.6
                                    dragScale = 1.0 - (progress * 0.4)
                                    // 平滑变透明：从 1.0 到 0.3
                                    dragOpacity = 1.0 - (progress * 0.7)
                                }
                                .onEnded { value in
                                    // 判断是否达到收起阈值（位移超过 100pt）
                                    let distance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
                                    
                                    if distance > 100 {
                                        // 自动归位到右上角 minimized 状态
                                        withAnimation(.interpolatingSpring(stiffness: 280, damping: 22)) {
                                            isFortuneExpanded = false
                                            dragOffset = .zero
                                            dragScale = 1.0
                                            dragOpacity = 1.0
                                        }
                                    } else {
                                        // 回弹到原始状态
                                        withAnimation(.interpolatingSpring(stiffness: 280, damping: 22)) {
                                            dragOffset = .zero
                                            dragScale = 1.0
                                            dragOpacity = 1.0
                                        }
                                    }
                                }
                        )
                } else {
                    // 右上角挂坠
                    minimizedFortunePendant
                        .position(
                            x: geometry.size.width - 44,
                            y: 100
                        )
                }
            }
        }
    }
    
    // MARK: - 右上角挂坠 (The Minimized Pendant)
    private var minimizedFortunePendant: some View {
        Button(action: {
            withAnimation(.interpolatingSpring(stiffness: 280, damping: 22)) {
                isFortuneExpanded = true
            }
        }) {
            ZStack {
                // 底座：44pt x 44pt 圆角正方形
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "#1A1A1A"))
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppTheme.Colors.babyBlue.opacity(0.3), lineWidth: 0.5)
                    )
                
                // 内容：星座符号或"籤"字
                if let zodiac = ZodiacUtil.loadZodiacSign() {
                    Text(String(zodiac.prefix(1)))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    Text("籤")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // 红点提醒
                if aiManager.todayFortune != nil {
                    Circle()
                        .fill(AppTheme.Colors.xhsRed)
                        .frame(width: 8, height: 8)
                        .position(x: 38, y: 6)
                }
            }
        }
        .matchedGeometryEffect(id: "fortuneCard", in: fortuneNS)
    }
    
    // MARK: - 全屏食签卡片 (The Expanded Milky Card) - 紧凑版
    private var expandedFortuneCard: some View {
        VStack(spacing: 0) {
            if let fortune = aiManager.todayFortune {
                // 顶部装饰区域 - 紧凑化
                VStack(spacing: 0) {
                    // 星座图标 + 运势标题
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.babyBlue)
                        
                        Text("今日食签")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.Colors.lightText)
                        
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.Colors.babyBlue)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                    
                    // Section 1: 星象（紧凑版）
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { index in
                            ZStack {
                                // 外发光效果（激活状态）
                                if index < fortune.fortuneStars {
                                    Circle()
                                        .fill(AppTheme.Colors.babyBlue.opacity(0.15))
                                        .frame(width: 16, height: 16)
                                        .blur(radius: 3)
                                }
                                
                                // 主圆球
                                Circle()
                                    .fill(index < fortune.fortuneStars ? 
                                          AppTheme.Colors.babyBlue : 
                                          Color.gray.opacity(0.08))
                                    .frame(width: 11, height: 11)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                index < fortune.fortuneStars ? 
                                                Color.white.opacity(0.4) : 
                                                Color.gray.opacity(0.1),
                                                lineWidth: 0.5
                                            )
                                    )
                            }
                        }
                    }
                    .padding(.bottom, 6)
                    
                    // 运势星级文字
                    Text("\(fortune.fortuneStars)星运势")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(AppTheme.Colors.babyBlue)
                        .padding(.bottom, 16)
                }
                
                // Section 2: 主解析（紧凑版）
                Text(fortune.analysis)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(AppTheme.Colors.darkText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 20)
                
                // 分隔装饰线 - 简化
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.12))
                        .frame(height: 0.5)
                    
                    Image(systemName: "star.fill")
                        .font(.system(size: 7))
                        .foregroundColor(Color.gray.opacity(0.25))
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.12))
                        .frame(height: 0.5)
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 20)
                
                // Section 3: 宜/忌核心（紧凑版）
                VStack(spacing: 16) {
                    // 宜
                    VStack(spacing: 6) {
                        // 标签 + 内容同行
                        HStack(spacing: 8) {
                            // 宜标签
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(AppTheme.Colors.xhsRed)
                                    .frame(width: 5, height: 5)
                                
                                Text("宜")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.xhsRed)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(AppTheme.Colors.xhsRed.opacity(0.08))
                            )
                            
                            // 宜内容
                            Text(fortune.yiHighlight)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.Colors.xhsRed)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        
                        // 宜说明
                        Text(fortune.yiSub)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.Colors.lightText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 28)
                    }
                    
                    // 中间分隔（简化）
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color.gray.opacity(0.3))
                    
                    // 忌
                    VStack(spacing: 6) {
                        // 标签 + 内容同行
                        HStack(spacing: 8) {
                            // 忌标签
                            HStack(spacing: 4) {
                                Circle()
                                    .stroke(AppTheme.Colors.darkText.opacity(0.6), lineWidth: 1)
                                    .frame(width: 5, height: 5)
                                
                                Text("忌")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.darkText.opacity(0.7))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.gray.opacity(0.08))
                            )
                            
                            // 忌内容
                            Text(fortune.jiHighlight)
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.Colors.darkText)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        
                        // 忌说明
                        Text(fortune.jiSub)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(AppTheme.Colors.lightText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .padding(.horizontal, 28)
                    }
                }
                .padding(.bottom, 20)
                
                // 分隔装饰线 - 简化
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.12))
                        .frame(height: 0.5)
                    
                    Image(systemName: "fork.knife")
                        .font(.system(size: 9))
                        .foregroundColor(Color.gray.opacity(0.25))
                    
                    Rectangle()
                        .fill(Color.gray.opacity(0.12))
                        .frame(height: 0.5)
                }
                .padding(.horizontal, 36)
                .padding(.bottom, 16)
                
                // Section 4: 转运食物（紧凑版）
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(AppTheme.Colors.babyBlue)
                    
                    Text(fortune.luckFood)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.Colors.babyBlue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(AppTheme.Colors.babyBlue.opacity(0.1))
                )
                .padding(.bottom, 16)
                
                // Section 5: 背书（紧凑版）
                VStack(spacing: 4) {
                    Text("—— 结合你的星盘与今日黄历解析 ——")
                        .font(.system(size: 10, weight: .regular, design: .rounded))
                        .italic()
                        .foregroundColor(AppTheme.Colors.lightText.opacity(0.7))
                    
                    Text("基于您的星座与来到这个世界的日子")
                        .font(.system(size: 8, weight: .regular, design: .rounded))
                        .foregroundColor(AppTheme.Colors.lightText.opacity(0.45))
                        .tracking(0.3)
                }
                .padding(.bottom, 20)
                
            } else {
                // 加载中状态 - 紧凑版
                LoadingFortuneView()
                    .padding(.vertical, 50)
            }
        }
        .background(
            ZStack {
                // 白色背景
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white)
                
                // 星轨圆环纹理（占星术神秘感）- 优化后的纹理
                GeometryReader { geometry in
                    ZStack {
                        // 外圈（更淡）
                        Circle()
                            .stroke(Color.gray.opacity(0.025), lineWidth: 1)
                            .frame(width: geometry.size.width * 0.95, height: geometry.size.width * 0.95)
                            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.4)
                        
                        // 中圈
                        Circle()
                            .stroke(Color.gray.opacity(0.02), lineWidth: 1)
                            .frame(width: geometry.size.width * 0.75, height: geometry.size.width * 0.75)
                            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.4)
                        
                        // 内圈
                        Circle()
                            .stroke(Color.gray.opacity(0.015), lineWidth: 1)
                            .frame(width: geometry.size.width * 0.55, height: geometry.size.width * 0.55)
                            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.4)
                        
                        // 偏心小圆（模拟行星轨道）
                        Circle()
                            .stroke(Color.gray.opacity(0.02), lineWidth: 0.5)
                            .frame(width: 80, height: 80)
                            .position(x: geometry.size.width * 0.85, y: geometry.size.height * 0.15)
                        
                        // 柔和连接线
                        Path { path in
                            path.move(to: CGPoint(x: geometry.size.width * 0.1, y: geometry.size.height * 0.25))
                            path.addCurve(
                                to: CGPoint(x: geometry.size.width * 0.9, y: geometry.size.height * 0.55),
                                control1: CGPoint(x: geometry.size.width * 0.3, y: geometry.size.height * 0.35),
                                control2: CGPoint(x: geometry.size.width * 0.7, y: geometry.size.height * 0.45)
                            )
                        }
                        .stroke(Color.gray.opacity(0.02), lineWidth: 0.5)
                    }
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 12)
        .matchedGeometryEffect(id: "fortuneCard", in: fortuneNS)
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
                withAnimation(.interpolatingSpring(stiffness: 280, damping: 22)) {
                    isFortuneExpanded = true
                    hasShownToday = true
                }
                
                // 记录今天已展示
                UserDefaults.standard.set(today, forKey: "last_fortune_shown_date")
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
    
    // MARK: - 筛选胶囊标签（与 LibraryView 同步）
    private func filterCapsuleLabel(title: String, isSelected: Bool) -> some View {
        let displayTitle = title.count > 4 ? String(title.prefix(3)) + "…" : title
        
        return HStack(spacing: 4) {
            Text(displayTitle)
                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : Color(hex: "#1A1A1A"))
                .frame(width: 52, height: 18, alignment: .center)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 7))
                .foregroundColor(isSelected ? .white.opacity(0.8) : AppTheme.Colors.babyBlue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? Color.black : Color.white)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }
    
    // MARK: - Cover Flow 卡片轮播区域
    private func carouselArea(cardWidth: CGFloat, cardHeight: CGFloat, containerWidth: CGFloat) -> some View {
        Group {
            if filteredRestaurants.isEmpty {
                emptyStateView
            } else {
                let cardSpacing: CGFloat = 0
                let totalCardWidth = cardWidth + cardSpacing
                // 内容边距：使第一个卡片居中
                let contentMargin = (containerWidth - cardWidth) / 2
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: cardSpacing) {
                        ForEach(Array(filteredRestaurants.enumerated()), id: \.element.id) { index, restaurant in
                            // 关键：使用单一状态控制 Hero Animation
                            // 未选中时 isSource = true（作为源）
                            // 选中时 isSource = false（作为目标）
                            GourmetMatchCard(
                                restaurant: restaurant,
                                locationManager: locationManager,
                                cardWidth: cardWidth,
                                cardHeight: cardHeight
                            )
                            .matchedGeometryEffect(
                                id: restaurant.id,
                                in: animation,
                                isSource: selectedRestaurant?.id != restaurant.id
                            )
                            .frame(width: cardWidth, height: cardHeight)
                            .visualEffect { content, proxy in
                                // 获取卡片在全局坐标系中的位置（相对于屏幕）
                                let frame = proxy.frame(in: .global)
                                // 卡片中心在屏幕上的 X 坐标
                                let cardCenterX = frame.midX
                                // 屏幕中心 X 坐标
                                let screenCenterX = containerWidth / 2
                                // 计算距离（有符号，用于旋转方向）
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
                                // 关键：只有当没有选中卡片时才允许点击
                                // 使用单一状态 selectedRestaurant 控制
                                guard selectedRestaurant == nil else { return }
                                
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                    selectedRestaurant = restaurant
                                }
                            }
                            // 检测是否滑动到中心，触发震动反馈和文案更新
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .global)
                            } action: { frame in
                                let cardCenterX = frame.midX
                                let screenCenterX = containerWidth / 2
                                let distance = abs(screenCenterX - cardCenterX)
                                
                                // 如果距离中心小于阈值，认为是中心卡片
                                if distance < 10 {
                                    // 更新当前中心索引（带动画）
                                    if currentCenterIndex != index {
                                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                            currentCenterIndex = index
                                        }
                                    }
                                    
                                    // 触发震动反馈（只触发一次）
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
                // 计算边距使第一个卡片居中
                .contentMargins(.horizontal, contentMargin, for: .scrollContent)
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

// MARK: - 底部详情卡片（非全屏，参考图2/3样式）
struct GourmetMatchDetailCard: View {
    let restaurant: Restaurant
    var namespace: Namespace.ID
    let locationManager: LocationManager
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 拖动指示条
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // 图片区域（与卡片共用 Hero 动画）
                    // 关键：isSource = true，作为动画的目标
                    AsyncImageView(
                        filename: restaurant.coverPhotoFilename,
                        placeholder: AnyView(
                            ZStack {
                                AppTheme.Colors.babyBlue.opacity(0.1)
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(AppTheme.Colors.babyBlue.opacity(0.3))
                            }
                        )
                    )
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .matchedGeometryEffect(id: restaurant.id, in: namespace, isSource: true)
                    
                    // 内容区域（参考图3样式）
                    VStack(alignment: .leading, spacing: 16) {
                        // 标题行
                        HStack {
                            Text(restaurant.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(AppTheme.Colors.darkText)
                            
                            Spacer()
                            
                            // 评分
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.yellow)
                                Text("\(restaurant.rating, specifier: "%.0f")")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(AppTheme.Colors.darkText)
                            }
                        }
                        
                        // 距离和预计时间（参考图3的蓝色样式）
                        HStack(spacing: 24) {
                            if let userLocation = locationManager.userLocation {
                                let distance = userLocation.distance(from: CLLocation(
                                    latitude: restaurant.latitude,
                                    longitude: restaurant.longitude
                                ))
                                let distanceText = distance < 1000 ? String(format: "%.1f", distance) : String(format: "%.1f", distance / 1000)
                                let unit = distance < 1000 ? "m" : "km"
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 12))
                                        Text("\(distanceText) \(unit)")
                                            .font(.system(size: 16, weight: .semibold))
                                    }
                                    .foregroundColor(AppTheme.Colors.babyBlue)
                                    
                                    Text("距离")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.Colors.lightText)
                                }
                                
                                // 预计驾车时间（估算）
                                let drivingMinutes = Int(distance / 500)
                                if drivingMinutes > 0 {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "car.fill")
                                                .font(.system(size: 12))
                                            Text("\(drivingMinutes) 分钟")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .foregroundColor(AppTheme.Colors.babyBlue)
                                        
                                        Text("预计驾车")
                                            .font(.system(size: 11))
                                            .foregroundColor(AppTheme.Colors.lightText)
                                    }
                                }
                            }
                        }
                        
                        // 一句话点评
                        if !restaurant.review.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("一句话点评")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(AppTheme.Colors.lightText)
                                
                                Text(restaurant.review)
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.Colors.darkText)
                            }
                        }
                        
                        // 统计信息（参考图3的图标+数字样式）
                        HStack(spacing: 24) {
                            if restaurant.averagePrice > 0 {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Colors.babyBlue)
                                        Text("¥\(Int(restaurant.averagePrice))")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(AppTheme.Colors.darkText)
                                    }
                                    Text("人均消费")
                                        .font(.system(size: 11))
                                        .foregroundColor(AppTheme.Colors.lightText)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.babyBlue)
                                    Text("\(restaurant.checkInCount)")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.darkText)
                                }
                                Text("已造访")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Colors.lightText)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "creditcard.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.Colors.babyBlue)
                                    Text("¥\(Int(restaurant.totalExpense))")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AppTheme.Colors.darkText)
                                }
                                Text("总消费")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Colors.lightText)
                            }
                        }
                        
                        // 标签
                        if !restaurant.tags.isEmpty {
                            GourmetMatchFlowLayout(spacing: 8) {
                                ForEach(restaurant.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(AppTheme.Colors.mediumGray)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(AppTheme.Colors.softBackground)
                                        )
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            
            // 底部操作按钮（参考图3样式）
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    // 打卡按钮
                    Button {
                        // 打卡逻辑
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 16))
                            Text("打卡")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(AppTheme.Colors.darkText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.softBackground)
                        )
                    }
                    
                    // 导航按钮
                    Button {
                        // 导航逻辑
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.turn.up.right")
                                .font(.system(size: 16))
                            Text("导航")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(AppTheme.Colors.darkText)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(AppTheme.Colors.softBackground)
                        )
                    }
                    
                    Spacer()
                    
                    // 关闭按钮
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.Colors.lightText)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.white)
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 30, x: 0, y: -10)
        .frame(maxHeight: 600)
        .padding(.horizontal, 16)
        .padding(.bottom, 90)
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
