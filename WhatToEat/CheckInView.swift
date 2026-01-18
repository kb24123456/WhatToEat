//
//  CheckInView.swift
//  WhatToEat
//
//  Created by 廖云丰 on 2026/1/17.
//

import SwiftUI
import SwiftData
import UIKit
import PhotosUI

struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let restaurant: Restaurant
    var editingLog: VisitLog? = nil
    
    // 表单数据
    @State private var date = Date()
    @State private var peopleCount = 2
    @State private var expense = 0.0
    @State private var goodDishes = ""
    @State private var badDishes = ""
    @State private var review = ""
    
    // 照片相关
    @State private var selectedImage: UIImage?
    
    // 状态变量
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    
    // 辅助计算属性
    private var currentPerPersonPrice: Double {
        if peopleCount > 0 {
            return expense / Double(peopleCount)
        } else {
            return 0.0
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 1. 基本信息
                basicInfoSection
                
                // 2. 红黑榜
                redBlackListSection
                
                // 3. 用餐照片 (最复杂的部分，已拆分)
                photoSection
                
                // 4. 评价
                reviewSection
            }
            .navigationTitle(editingLog != nil ? "编辑打卡" : "打卡")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            // 表单回填（编辑模式）
            .onAppear {
                if let log = editingLog {
                    // 数据回填
                    date = log.date
                    expense = log.expense
                    peopleCount = log.peopleCount
                    goodDishes = log.goodDishes
                    badDishes = log.badDishes
                    review = log.review
                    
                    // 图片加载（在后台线程）
                    Task {
                        if let filename = log.photoFilename {
                            let image = ImageManager.shared.loadImage(filename: filename)
                            await MainActor.run { self.selectedImage = image }
                        }
                    }
                }
            }
            
            // 弹窗与选择器配置
            .confirmationDialog("选择照片来源", isPresented: $showActionSheet, titleVisibility: .visible) {
                Button("📸 拍照") { showCamera = true }
                Button("🖼️ 从相册选择") { showPhotoPicker = true }
                Button("取消", role: .cancel) { }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(selectedImage: $selectedImage)
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
            .onChange(of: photoPickerItem) { oldValue, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let image = UIImage(data: data) {
                            await MainActor.run { self.selectedImage = image }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveCheckIn() }
                        .disabled(expense <= 0)
                }
            }
        }
    }
    
    // MARK: - 拆分的视图模块 (解决编译器超时)
    
    @ViewBuilder
    private var basicInfoSection: some View {
        Section {
            DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
            
            Stepper("人数: \(peopleCount)", value: $peopleCount, in: 1...20)
            
            TextField("消费金额", value: $expense, format: .currency(code: "CNY"))
                .keyboardType(.decimalPad)
            
            Text("本次人均: \(currentPerPersonPrice.formatted(.currency(code: "CNY")))")
                .foregroundColor(.gray)
        } header: {
            Text("基本信息")
        }
    }
    
    @ViewBuilder
    private var redBlackListSection: some View {
        Section {
            TextField("红榜菜品", text: $goodDishes, prompt: Text("好吃的菜品"))
            TextField("黑榜菜品", text: $badDishes, prompt: Text("不好吃的菜品"))
        } header: {
            Text("红黑榜")
        }
    }
    
    @ViewBuilder
    private var photoSection: some View {
        Section {
            if let image = selectedImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(8)
                    
                    Button(action: { selectedImage = nil }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                    }
                    .padding(8)
                }
            } else {
                Button(action: { showActionSheet = true }) {
                    VStack(spacing: 12) {
                        Image(systemName: "camera")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("添加照片")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("用餐照片")
        }
    }
    
    @ViewBuilder
    private var reviewSection: some View {
        Section {
            // ✅ 修改后： axis 设为垂直，评价再长也会向下自动换行
            TextField("分享你的用餐体验", text: $review, axis: .vertical)
                .lineLimit(3...6) // 限制最小3行，最大6行
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .frame(minHeight: 80)
        } header: {
            Text("评价")
        }
    }
    
    // MARK: - 逻辑处理
    
    private func saveCheckIn() {
        // ⚠️ 删掉 perPersonPrice 的手动计算和赋值逻辑，因为模型会自动算
        
        if let editingLog = editingLog {
            // 编辑现有记录
            editingLog.date = date
            editingLog.peopleCount = peopleCount
            editingLog.expense = expense
            // ✅ 删掉下面这一行（因为 VisitLog 已经没有这个成员了）：
            // editingLog.averagePrice = perPersonPrice
            
            editingLog.goodDishes = goodDishes
            editingLog.badDishes = badDishes
            editingLog.review = review
            
            // 更新照片
            updatePhotoForLog(log: editingLog)
        } else {
            // 创建新记录
            // ✅ 修正：删掉参数中的 averagePrice
            let newLog = VisitLog(
                date: date,
                expense: expense,      // ✅ 先写 expense
                peopleCount: peopleCount,  // ✅ 再写 peopleCount
                goodDishes: goodDishes,
                badDishes: badDishes,
                review: review
            )
            
            // 更新照片
            updatePhotoForLog(log: newLog)
            
            // 添加到餐厅
            restaurant.logs.append(newLog)
        }
        
        // 更新餐厅的平均消费
        updateRestaurantAveragePrice()
        
        dismiss()
    }

    
    // 更新打卡记录的照片
    private func updatePhotoForLog(log: VisitLog) {
        // 保存旧照片文件名，用于后续删除
        let oldFilename = log.photoFilename
        
        // 如果有新照片，保存并更新文件名
        if let newImage = selectedImage {
            if let newFilename = ImageManager.shared.saveImage(newImage) {
                log.photoFilename = newFilename
            }
        } else if log.photoFilename != nil {
            // 如果没有新照片，但之前有照片，清除照片
            log.photoFilename = nil
        }
        
        // 如果有旧照片且与新照片不同，删除旧照片
        if let oldFilename = oldFilename, log.photoFilename != oldFilename {
            ImageManager.shared.deleteImage(filename: oldFilename)
        }
    }
    
    // 更新餐厅的平均消费
    private func updateRestaurantAveragePrice() {
        if restaurant.logs.isEmpty {
            restaurant.averagePrice = 0.0
        } else {
            // ✅ 修正：手动计算每一条记录的人均，然后求总平均
            // 这样即使模型里没存这个数，我们也能算出来
            let totalPerPersonSum = restaurant.logs.reduce(0.0) { partialResult, log in
                let perPerson = log.peopleCount > 0 ? log.expense / Double(log.peopleCount) : 0.0
                return partialResult + perPerson
            }
            
            restaurant.averagePrice = totalPerPersonSum / Double(restaurant.logs.count)
        }
    }
}
