import SwiftUI
import MapKit
import SwiftData
import UIKit
import PhotosUI

struct RestaurantDetailView: View {
    let restaurant: Restaurant
    @Environment(\.modelContext) private var modelContext
    let locationManager: LocationManager
    
    // 驾车路线信息
    @State private var drivingRoute: (distance: String, time: String)?
    @State private var isLoadingRoute = false
    
    // 弹窗控制
    @State private var showSheet = false
    @State private var logToEdit: VisitLog? = nil
    
    // 封面图更换相关
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var selectedNewCover: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // 1. 顶部大封面图
                coverImageSection
                
                VStack(alignment: .leading, spacing: 20) {
                    // 2. 标题和分类标签
                    titleSection
                    
                    // 2.5 统计卡片
                    statsCardSection
                    
                    // 3. 餐厅标签
                    tagsSection
                    
                    // 4. 路线信息
                    routeInfoSection
                    
                    // 5. 餐厅印象评价
                    restaurantReviewSection
                    
                    // 6. 打卡按钮
                    checkInButton
                    
                    // 7. 核心：详细打卡记录列表
                    checkInHistoryList
                }
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("餐厅详情")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGray6))
        .task { await fetchDrivingRoute() }
        // 当编辑完回来或者新增完回来时，确保 UI 刷新
        .sheet(isPresented: $showSheet) {
            CheckInView(restaurant: restaurant, editingLog: logToEdit)
        }
        // 封面图更换菜单
        .confirmationDialog("更换封面图", isPresented: $showActionSheet) {
            Button("📸 拍照") { showCamera = true }
            Button("🖼️ 从相册选择") { showPhotoPicker = true }
            if restaurant.coverPhotoFilename != nil {
                Button("🗑️ 删除封面", role: .destructive) {
                    restaurant.coverPhotoFilename = nil
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(selectedImage: $selectedNewCover)
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem)
        .onChange(of: selectedNewCover) { oldValue, newValue in
            if let image = newValue { updateCover(image: image) }
        }
    }

    // MARK: - 1. 封面图
    @ViewBuilder
    private var coverImageSection: some View {
        AsyncImageView(
            filename: restaurant.coverPhotoFilename,
            placeholder: AnyView(
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 250)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    )
            )
        )
        // AsyncImageView内部已经处理了resizable和aspectRatio，不需要外部调用
        .frame(height: 250)
        .clipped()
        .onTapGesture { showActionSheet = true }
    }

    // MARK: - 2. 标题区
    @ViewBuilder
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(restaurant.name)
                .font(.title).bold()
            
            HStack {
                Text(restaurant.type).font(.caption).padding(6).background(Color.blue.opacity(0.1)).foregroundColor(.blue).cornerRadius(4)
                Text("⭐️ \(restaurant.rating)").font(.caption).padding(6).background(Color.orange.opacity(0.1)).foregroundColor(.orange).cornerRadius(4)
                Text(restaurant.district).font(.caption).padding(6).background(Color.green.opacity(0.1)).foregroundColor(.green).cornerRadius(4)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - 2.5 统计卡片
    @ViewBuilder
    private var statsCardSection: some View {
        HStack(spacing: 1) {
            // 左侧：收录时间
            VStack(alignment: .center, spacing: 4) {
                Text("📅 收录时间")
                    .font(AppTheme.Fonts.footnote)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text(restaurant.recordTimeDisplay)
                    .font(AppTheme.Fonts.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.card)
            
            // 右侧：累计打卡
            VStack(alignment: .center, spacing: 4) {
                Text("🔥 累计打卡")
                    .font(AppTheme.Fonts.footnote)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                Text("\(restaurant.checkInCount) 次")
                    .font(AppTheme.Fonts.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.Colors.card)
        }
        .cornerRadius(AppTheme.Radius.sm)
        .padding(.horizontal)
    }
    
    // MARK: - 3. 标签区
    @ViewBuilder
    private var tagsSection: some View {
        if !restaurant.tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(restaurant.tags, id: \.self) { tag in
                        Text("# \(tag)")
                            .font(.caption)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - 4. 路线信息
    @ViewBuilder
    private var routeInfoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(restaurant.address, systemImage: "mappin.and.ellipse")
                .font(.footnote)
                .foregroundColor(.gray)
            
            if isLoadingRoute {
                ProgressView()
            } else if let route = drivingRoute {
                Text("🚗 驾车耗时: \(route.time) (\(route.distance))")
                    .font(.footnote).bold()
                    .foregroundColor(.green)
            }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white).cornerRadius(12).padding(.horizontal)
    }

    // MARK: - 5. 餐厅评价
    @ViewBuilder
    private var restaurantReviewSection: some View {
        if !restaurant.review.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("我的印象").font(.subheadline).bold()
                Text(restaurant.review).font(.footnote).foregroundColor(.secondary)
            }
            .padding().frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white).cornerRadius(12).padding(.horizontal)
        }
    }

    // MARK: - 6. 打卡按钮
    @ViewBuilder
    private var checkInButton: some View {
        Button {
            logToEdit = nil
            showSheet = true
        } label: {
            HStack {
                Image(systemName: "pencil.and.outline")
                Text("我要打卡")
            }
            .font(.headline).frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(12)
        }
        .padding(.horizontal)
    }

    // MARK: - 7. 打卡历史记录（重头戏）
    @ViewBuilder
    private var checkInHistoryList: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("打卡记录 (\(restaurant.logs.count))")
                .font(.headline)
                .padding(.horizontal)
            
            if restaurant.logs.isEmpty {
                Text("暂无记录，快去打卡吧！")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ForEach(restaurant.logs.sorted(by: { $0.date > $1.date })) { log in
                    VStack(alignment: .leading, spacing: 12) {
                        // 顶部信息
                        HStack {
                            Text(log.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline).bold()
                            Spacer()
                            // 计算人均
                            let perPerson = log.peopleCount > 0 ? log.expense / Double(log.peopleCount) : 0
                            Text("人均 ¥\(Int(perPerson))")
                                .font(.caption).bold().foregroundColor(.green)
                        }
                        
                        // 打卡照片：使用 AsyncImageView 实现异步加载和预解码
                        AsyncImageView(
                            filename: log.photoFilename,
                            placeholder: AnyView(EmptyView())
                        )
                        // AsyncImageView内部已经处理了resizable和aspectRatio，不需要外部调用
                        .frame(height: log.photoFilename != nil ? 180 : 0)
                        .clipped()
                        .cornerRadius(8)
                        
                        // 详情数据
                        Text("消费 ¥\(Int(log.expense)) • \(log.peopleCount)人用餐")
                            .font(.caption).foregroundColor(.gray)
                        
                        // 红黑榜
                        if !log.goodDishes.isEmpty || !log.badDishes.isEmpty {
                            HStack(spacing: 12) {
                                if !log.goodDishes.isEmpty {
                                    Text("👍 \(log.goodDishes)").font(.caption).foregroundColor(.red)
                                }
                                if !log.badDishes.isEmpty {
                                    Text("💣 \(log.badDishes)").font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // 点评
                        if !log.review.isEmpty {
                            Text(log.review)
                                .font(.footnote)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    // ✅ 长按弹出编辑/删除菜单
                    .contextMenu {
                        Button {
                            logToEdit = log
                            showSheet = true
                        } label: {
                            Label("编辑这条记录", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            modelContext.delete(log)
                            restaurant.updateAveragePrice()
                        } label: {
                            Label("删除这条记录", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - 辅助逻辑
    private func fetchDrivingRoute() async {
        guard locationManager.userLocation != nil else { return }
        isLoadingRoute = true
        if let info = await locationManager.fetchRoute(to: restaurant.latitude, long: restaurant.longitude) {
            drivingRoute = info
        }
        isLoadingRoute = false
    }

    private func updateCover(image: UIImage) {
        if let filename = ImageManager.shared.saveImage(image) {
            restaurant.coverPhotoFilename = filename
        }
    }
}
