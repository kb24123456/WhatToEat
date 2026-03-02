//
//  MasonryGridView.swift
//  WhatToEat
//
//  Created by AI Assistant on 2026/2/27.
//

import SwiftUI

// MARK: - Masonry Grid Layout
// 两列瀑布流布局组件，支持不同高度的卡片

struct MasonryGrid<Content: View>: View {
    let columns: Int
    let spacing: CGFloat
    let content: Content
    
    init(columns: Int = 2, spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.columns = columns
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(0..<columns, id: \.self) { columnIndex in
                MasonryColumn(columnIndex: columnIndex, totalColumns: columns, spacing: spacing) {
                    content
                }
            }
        }
    }
}

// MARK: - Masonry Column
private struct MasonryColumn<Content: View>: View {
    let columnIndex: Int
    let totalColumns: Int
    let spacing: CGFloat
    let content: Content
    
    init(columnIndex: Int, totalColumns: Int, spacing: CGFloat, @ViewBuilder content: () -> Content) {
        self.columnIndex = columnIndex
        self.totalColumns = totalColumns
        self.spacing = spacing
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: spacing) {
            content
                .environment(\.masonryColumnIndex, columnIndex)
                .environment(\.masonryTotalColumns, totalColumns)
        }
    }
}

// MARK: - Masonry Item
// 用于在瀑布流中放置子视图，按顺序交替分配到列

struct MasonryItem<Content: View>: View {
    let id: AnyHashable
    let content: Content
    
    @Environment(\.masonryColumnIndex) private var columnIndex
    @Environment(\.masonryTotalColumns) private var totalColumns
    
    // 使用静态计数器来跟踪项目顺序
    @State private var itemIndex: Int = 0
    
    init(id: some Hashable, @ViewBuilder content: () -> Content) {
        self.id = AnyHashable(id)
        self.content = content()
    }
    
    var body: some View {
        // 使用 id 的 hash 值来确定顺序，确保每次渲染一致
        let hash = id.hashValue
        let targetColumn = abs(hash) % (totalColumns ?? 2)
        
        if targetColumn == columnIndex {
            content
        }
    }
}

// MARK: - Environment Keys
private struct MasonryColumnIndexKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

private struct MasonryTotalColumnsKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    var masonryColumnIndex: Int? {
        get { self[MasonryColumnIndexKey.self] }
        set { self[MasonryColumnIndexKey.self] = newValue }
    }
    
    var masonryTotalColumns: Int? {
        get { self[MasonryTotalColumnsKey.self] }
        set { self[MasonryTotalColumnsKey.self] = newValue }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        MasonryGrid(columns: 2, spacing: 8) {
            ForEach(0..<10) { index in
                MasonryItem(id: index) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: CGFloat.random(in: 100...250))
                        .overlay(
                            Text("\(index)")
                                .font(.largeTitle)
                        )
                }
            }
        }
        .padding(.horizontal, 24)
    }
}
