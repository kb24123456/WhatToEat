import SwiftUI

// 注意：FlowLayout 定义在 RestaurantFlowView.swift 中
// 此视图使用 RestaurantFlowView 中定义的 FlowLayout

struct ExpandedInfoView: View {
    let restaurant: Restaurant
    let cascadePhase: Int
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            titleSection
                .padding(.top, 24)
                .opacity(cascadePhase >= 1 ? 1 : 0)
                .offset(y: cascadePhase >= 1 ? 0 : 30)
            
            dataGrid
                .padding(.top, 20)
                .opacity(cascadePhase >= 2 ? 1 : 0)
                .offset(y: cascadePhase >= 2 ? 0 : 30)
            
            reviewSection
                .padding(.top, 20)
                .opacity(cascadePhase >= 3 ? 1 : 0)
                .offset(y: cascadePhase >= 3 ? 0 : 30)
            
            tagsSection
                .padding(.top, 20)
                .opacity(cascadePhase >= 4 ? 1 : 0)
                .offset(y: cascadePhase >= 4 ? 0 : 30)
            
            actionButton
                .padding(.top, 30)
                .padding(.bottom, 40)
                .opacity(cascadePhase >= 5 ? 1 : 0)
                .offset(y: cascadePhase >= 5 ? 0 : 30)
        }
        .padding(.horizontal, 20)
    }
    
    private var titleSection: some View {
        Text(restaurant.name)
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var dataGrid: some View {
        HStack(spacing: 12) {
            DataCell(icon: "location.fill", value: "5.7km", label: "距离")
            DataCell(icon: "car.fill", value: "11min", label: "驾车")
            DataCell(icon: "mappin", value: restaurant.district, label: "区域")
            DataCell(icon: "fork.knife", value: restaurant.type, label: "品类")
        }
    }
    
    private var reviewSection: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(AppTheme.Colors.babyBlue)
                .frame(width: 4, height: 50)
            
            Text(restaurant.review)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.08))
        )
    }
    
    private var tagsSection: some View {
        // 使用自定义的 TagFlowLayout 避免与 RestaurantFlowView 的 FlowLayout 冲突
        TagFlowLayout(spacing: 8) {
            ForEach(restaurant.tags, id: \.self) { tag in
                TagPill(text: tag)
            }
        }
    }
    
    private var actionButton: some View {
        Button(action: onClose) {
            Text("去这里")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black)
                        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 8)
                )
        }
    }
}

struct DataCell: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(AppTheme.Colors.babyBlue)
            
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
}

struct TagPill: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.12))
            )
    }
}

// MARK: - 独立的 TagFlowLayout（避免与 RestaurantFlowView 的 FlowLayout 冲突）
struct TagFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = TagFlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = TagFlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct TagFlowResult {
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
