import SwiftUI

// MARK: - 1. 数据模型
struct InteriorItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let description: String
    let color: Color // 模拟图片主色调
    let images: [String] // 实际项目中这里是图片名
}

let sampleItems: [InteriorItem] = [
    InteriorItem(title: "Quiet Blue", description: "A quiet, light-filled space designed for deep rest.", color: Color.blue.opacity(0.1), images: ["bed.double", "lamp.table", "pillow"]),
    InteriorItem(title: "The Study", description: "Simple, focused, and serene. Designed for clarity.", color: Color.purple.opacity(0.1), images: ["chair.lounge", "books.vertical", "pencil"]),
    InteriorItem(title: "Warm Living", description: "Where light and texture come together.", color: Color.orange.opacity(0.1), images: ["sofa", "fireplace", "rug"]),
    InteriorItem(title: "Green Corner", description: "Nature brought indoors for peace.", color: Color.green.opacity(0.1), images: ["leaf", "tree", "bird"])
]

// MARK: - 2. 主视图 (Orchestrator)
struct CosyLivingApp: View {
    // 状态管理
    @Namespace private var animation
    @State private var selectedItem: InteriorItem?
    @State private var isDetailViewVisible = false
    
    var body: some View {
        ZStack {
            // 背景色
            Color(UIColor.systemBackground).ignoresSafeArea()
            
            if let selectedItem, isDetailViewVisible {
                // MARK: 详情模式 (Detail View)
                DetailView(item: selectedItem, namespace: animation) {
                    // 关闭详情页的逻辑
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        isDetailViewVisible = false
                        self.selectedItem = nil
                    }
                }
                .zIndex(1) // 确保在最上层
            } else {
                // MARK: 列表模式 (Carousel)
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Welcome to")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Cosy Living")
                            .font(.largeTitle.bold())
                    }
                    .padding(.top, 50)
                    .opacity(isDetailViewVisible ? 0 : 1) // 详情页时隐藏标题
                    
                    // The Carousel
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) { // spacing 由 visualEffect 控制
                            ForEach(sampleItems) { item in
                                CardView(item: item)
                                    .matchedGeometryEffect(id: item.id, in: animation)
                                    .frame(width: 300, height: 420)
                                    // 核心：iOS 17 视觉效果 modifier
                                    .visualEffect { content, geometryProxy in
                                        content
                                            .scaleEffect(scale(for: geometryProxy))
                                            .opacity(opacity(for: geometryProxy))
                                            // 可选：添加轻微的3D旋转
                                            .rotation3DEffect(
                                                .degrees(rotation(for: geometryProxy)),
                                                axis: (x: 0, y: 1, z: 0)
                                            )
                                    }
                                    .padding(.horizontal, 20)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                            self.selectedItem = item
                                            self.isDetailViewVisible = true
                                        }
                                    }
                            }
                        }
                        .scrollTargetLayout() // 标记 HStack 为滚动目标布局
                    }
                    .scrollTargetBehavior(.viewAligned) // 开启视图对齐吸附
                    .contentMargins(.horizontal, 40, for: .scrollContent) // 设置边距让第一个卡片居中
                }
            }
        }
    }
    
    // MARK: - 视觉计算逻辑 (Visual Math)
    // 根据卡片在 ScrollView 中的位置计算缩放比例
    func scale(for proxy: GeometryProxy) -> CGFloat {
        let frame = proxy.frame(in: .scrollView)
        let screenWidth = UIScreen.main.bounds.width
        let midX = frame.midX
        let centerScreen = screenWidth / 2
        
        // 计算距离中心的距离
        let distance = abs(centerScreen - midX)
        // 阈值：距离越远缩放越小
        let scale = 1.0 - (distance / screenWidth) * 0.3
        return max(scale, 0.8) // 最小缩放到 0.8
    }
    
    func opacity(for proxy: GeometryProxy) -> Double {
        let frame = proxy.frame(in: .scrollView)
        let distance = abs(UIScreen.main.bounds.width / 2 - frame.midX)
        return Double(1.0 - (distance / 1000)) // 距离越远越透明
    }
    
    func rotation(for proxy: GeometryProxy) -> Double {
        let frame = proxy.frame(in: .scrollView)
        let distance = frame.midX - UIScreen.main.bounds.width / 2
        // 轻微的 Y 轴旋转增强 3D 感
        return Double(distance / 20)
    }
}

// MARK: - 3. 卡片组件 (Card View)
struct CardView: View {
    let item: InteriorItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 图片区域
            ZStack {
                item.color
                Image(systemName: item.images.first ?? "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.gray.opacity(0.5))
                    .padding(40)
            }
            .frame(height: 220)
            .clipped()
            
            // 文本区域
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(item.title)
                        .font(.title2.bold())
                    Spacer()
                }
                
                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                
                Spacer()
                
                Button(action: {}) {
                    Text("Book Now")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(20)
            .background(Color.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// MARK: - 4. 详情视图 (Detail View)
struct DetailView: View {
    let item: InteriorItem
    var namespace: Namespace.ID
    var onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 自定义导航栏/关闭按钮
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(radius: 2)
                }
                .padding()
            }
            .background(item.color.opacity(0.5)) // 稍微扩展背景色到状态栏
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // 内嵌轮播图 (TabView)
                    TabView {
                        ForEach(item.images, id: \.self) { imgName in
                            ZStack {
                                item.color
                                Image(systemName: imgName)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(50)
                            }
                        }
                    }
                    .tabViewStyle(.page) // 分页样式
                    .frame(height: 350)
                    
                    // 文本内容
                    VStack(alignment: .leading, spacing: 20) {
                        Text(item.title)
                            .font(.largeTitle.bold())
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        
                        Text(item.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        Text("Simplicity is the ultimate sophistication. This room is designed to bring you the utmost comfort with minimal visual noise.")
                            .foregroundStyle(.secondary)
                        
                        // 更多模拟内容
                        ForEach(0..<3) { _ in
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.1))
                                .frame(height: 60)
                        }
                    }
                    .padding(24)
                }
            }
            
            // 底部固定按钮
            VStack {
                Divider()
                HStack {
                    VStack(alignment: .leading) {
                        Text("Total Price")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("$250 / night")
                            .font(.title3.bold())
                    }
                    Spacer()
                    Button("Book Now") { }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding()
                .background(Color.white)
            }
        }
        // 保持卡片形状在转场开始时一致，然后变为全屏
        .background(Color.white)
        .matchedGeometryEffect(id: item.id, in: namespace)
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    CosyLivingApp()
}
