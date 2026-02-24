# 餐厅品类自定义功能实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现用户自定义餐厅品类功能，允许在 RestaurantDetailView 和 AddRestaurantView 中创建新品类并持久化存储

**Architecture:** 
- 扩展现有 CategoryManager 支持用户自定义品类
- 使用 SwiftData 存储用户创建的品类
- 在 ExpandableCategoryView 中添加"+ 新品类"入口
- 弹出 Sheet 输入新品类名称

**Tech Stack:** SwiftUI, SwiftData, CategoryManager

---

## 前置分析

### 当前代码结构
- `CategoryManager.swift` - 品类管理器，管理预设品类
- `RestaurantDetailView.swift` - 餐厅详情页，使用 ExpandableCategoryView
- `AddRestaurantView.swift` - 添加餐厅页
- `ExpandableCategoryView` - 品类选择组件

### 需要修改的文件
1. `CategoryManager.swift` - 添加用户自定义品类支持
2. `RestaurantDetailView.swift` - 添加新品类创建 UI
3. `AddRestaurantView.swift` - 添加新品类创建 UI
4. 可能需要创建新的数据模型存储用户品类

---

## Task 1: 创建用户自定义品类数据模型

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/UserCategory.swift`

**Step 1: 定义 UserCategory 模型**

```swift
import Foundation
import SwiftData

/// 用户自定义品类
@Model
class UserCategory {
    var id: UUID
    var name: String
    var createdAt: Date
    var isActive: Bool
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.isActive = true
    }
}
```

**Step 2: 更新 SwiftData 模型容器**

在 `WhatToEatApp.swift` 或主应用文件中，确保 `UserCategory` 被添加到模型容器：

```swift
.modelContainer(for: [Restaurant.self, UserCategory.self])
```

---

## Task 2: 扩展 CategoryManager 支持用户自定义品类

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/CategoryManager.swift`

**Step 1: 添加用户品类管理方法**

```swift
import Foundation
import SwiftData

/// 品类管理器，统一管理应用中的所有餐厅品类
class CategoryManager {
    // MARK: - 单例模式
    static let shared = CategoryManager()
    private init() {}
    
    // ... 现有预设品类代码 ...
    
    // MARK: - 用户自定义品类管理
    
    /// 获取所有品类（预设 + 用户自定义）
    func getAllCategories(from restaurants: [Restaurant], context: ModelContext? = nil) -> [String] {
        var allCategories = presetCategories
        
        // 从餐厅数据中提取品类
        let restaurantCategories = restaurants.map { $0.type }
        allCategories.append(contentsOf: restaurantCategories)
        
        // 从数据库获取用户自定义品类
        if let context = context {
            let userCategories = fetchUserCategories(from: context)
            allCategories.append(contentsOf: userCategories.map { $0.name })
        }
        
        // 去重并排序
        return Array(Set(allCategories)).sorted()
    }
    
    /// 获取预设品类 + 用户自定义品类（用于选择列表）
    func getSelectableCategories(context: ModelContext) -> [String] {
        let userCategories = fetchUserCategories(from: context)
        let allCategories = presetCategories + userCategories.map { $0.name }
        return Array(Set(allCategories)).sorted()
    }
    
    /// 创建新品类
    func createCategory(name: String, context: ModelContext) throws -> UserCategory {
        // 验证：不能为空
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CategoryError.emptyName
        }
        
        // 验证：不能重复
        let existingCategories = fetchUserCategories(from: context)
        let allExistingNames = presetCategories + existingCategories.map { $0.name }
        
        if allExistingNames.contains(name) {
            throw CategoryError.duplicateName
        }
        
        // 创建新品类
        let newCategory = UserCategory(name: name)
        context.insert(newCategory)
        try context.save()
        
        return newCategory
    }
    
    /// 从数据库获取用户自定义品类
    private func fetchUserCategories(from context: ModelContext) -> [UserCategory] {
        let descriptor = FetchDescriptor<UserCategory>(
            predicate: #Predicate { $0.isActive == true },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            return try context.fetch(descriptor)
        } catch {
            print("获取用户品类失败: \(error)")
            return []
        }
    }
}

// MARK: - 错误类型
enum CategoryError: Error, LocalizedError {
    case emptyName
    case duplicateName
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "品类名称不能为空"
        case .duplicateName:
            return "该品类已存在"
        case .saveFailed(let error):
            return "保存失败: \(error.localizedDescription)"
        }
    }
}
```

---

## Task 3: 创建新品类输入 Sheet 组件

**Files:**
- Create: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/CreateCategorySheet.swift`

**Step 1: 实现 CreateCategorySheet**

```swift
import SwiftUI
import SwiftData

/// 创建新品类 Sheet
struct CreateCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var categoryName = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    let onCategoryCreated: (String) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // 标题
                Text("创建新品类")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .padding(.top, 20)
                
                // 输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("品类名称")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppTheme.Colors.mediumGray)
                    
                    TextField("例如：私房菜、融合菜", text: $categoryName)
                        .font(.system(size: 16, weight: .medium))
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(errorMessage != nil ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 20)
                
                // 错误提示
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
                
                // 确认按钮
                Button {
                    createCategory()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        Text("创建")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule()
                            .fill(categoryName.isEmpty ? Color.gray : AppTheme.Colors.accent)
                    )
                }
                .disabled(categoryName.isEmpty || isLoading)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .background(AppTheme.Colors.milkWhite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.mediumGray)
                }
            }
        }
    }
    
    private func createCategory() {
        isLoading = true
        errorMessage = nil
        
        do {
            let newCategory = try CategoryManager.shared.createCategory(
                name: categoryName.trimmingCharacters(in: .whitespacesAndNewlines),
                context: modelContext
            )
            
            // 触感反馈
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // 回调
            onCategoryCreated(newCategory.name)
            
            // 关闭 Sheet
            dismiss()
            
        } catch let error as CategoryError {
            errorMessage = error.errorDescription
            isLoading = false
            
            // 错误触感
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            
        } catch {
            errorMessage = "创建失败，请重试"
            isLoading = false
        }
    }
}
```

---

## Task 4: 修改 ExpandableCategoryView 支持创建新品类

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/RestaurantDetailView.swift`

**Step 1: 添加新品类入口到展开容器**

在 `ExpandableCategoryView` 中添加：

```swift
struct ExpandableCategoryView: View {
    // ... 现有属性 ...
    
    // 新增：控制创建品类 Sheet 显示
    @State private var showCreateSheet = false
    
    // 新增：用于获取用户自定义品类
    @Environment(\.modelContext) private var modelContext
    
    // 动态获取所有品类（预设 + 用户自定义）
    private var allCategories: [String] {
        CategoryManager.shared.getSelectableCategories(context: modelContext)
    }
    
    // MARK: - 展开状态：自适应高度矩形
    private var expandedContainer: some View {
        FlowLayout(spacing: 12) {
            // 显示所有品类
            ForEach(allCategories, id: \.self) { category in
                CategoryOptionButton(
                    category: category,
                    isSelected: currentCategory == category,
                    onTap: { selectCategory(category) }
                )
            }
            
            // 新增：创建新品类按钮
            Button {
                showCreateSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("新品类")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundColor(AppTheme.Colors.mediumGray)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .stroke(AppTheme.Colors.mediumGray.opacity(0.5), lineWidth: 1)
                        .background(Capsule().fill(Color.white))
                )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
        .sheet(isPresented: $showCreateSheet) {
            CreateCategorySheet { newCategoryName in
                // 创建后立即选中
                selectCategory(newCategoryName)
            }
            .presentationDetents([.height(300)])
            .presentationBackground(.white)
        }
    }
    
    // ... 其余代码保持不变 ...
}
```

---

## Task 5: 在 AddRestaurantView 中添加品类创建功能

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/AddRestaurantView.swift`

**Step 1: 检查当前品类选择实现**

查找 AddRestaurantView 中的品类选择代码，根据实现方式选择：
- 如果使用 `ExpandableCategoryView`，则自动获得新品类功能
- 如果使用其他方式，需要添加类似的新品类入口

---

## Task 6: 更新自动分类算法

**Files:**
- Modify: `/Users/papertiger/Desktop/WhatToEat/WhatToEat/CategoryManager.swift`

**Step 1: 添加语义匹配支持**

```swift
extension CategoryManager {
    /// 根据餐厅名称和描述自动推荐品类
    func recommendCategory(for name: String, description: String? = nil, context: ModelContext) -> String? {
        let allCategories = getSelectableCategories(context: context)
        let combinedText = "\(name) \(description ?? "")".lowercased()
        
        // 遍历所有品类进行语义匹配
        for category in allCategories {
            if let keywords = semanticKeywords[category] {
                for keyword in keywords {
                    if combinedText.contains(keyword.lowercased()) {
                        return category
                    }
                }
            }
        }
        
        return nil
    }
    
    /// 语义关键词映射（包含用户自定义品类）
    private var semanticKeywords: [String: [String]] {
        var keywords: [String: [String]] = [
            "火锅": ["火锅", "串串", "麻辣烫", "冒菜"],
            "面馆": ["面", "粉", "拉面", "刀削面"],
            "烧烤": ["烧烤", "烤串", "烤肉"],
            // ... 其他预设品类 ...
        ]
        
        // 用户自定义品类可以在这里动态添加关键词
        // 或者通过其他方式配置
        
        return keywords
    }
}
```

---

## Task 7: 测试验证

**测试场景：**
1. 在 RestaurantDetailView 中展开品类选择器
2. 点击"+ 新品类"按钮
3. 输入新品类名称（如"私房菜"）
4. 确认创建
5. 验证新品类立即被选中
6. 验证新品类出现在品类列表中
7. 重启 App 验证数据持久化
8. 测试重复创建相同名称的品类（应报错）
9. 测试创建空名称品类（应报错）

---

## 执行选项

**Plan complete and saved to `docs/plans/2025-02-24-custom-category-creation.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
