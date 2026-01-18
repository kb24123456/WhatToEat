import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    

    
    // 文件导入状态
    @State private var isImporting = false
    
    // 文本区域内容
    @State private var csvText = ""
    
    // 导入状态提示
    @State private var importMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Spacer()
                Text("导入数据")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .overlay(
                Divider()
                    .frame(height: 1)
                    .background(.gray.opacity(0.2))
                    .padding(.top, 44)
            )
            
            // 主要内容
            ScrollView {
                VStack(spacing: 20) {
                    // 文件上传区
                    VStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .foregroundColor(.red)
                        Text("点击上传 CSV")
                            .font(.system(size: 16, weight: .medium))
                        Text("支持 .csv 格式")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                    .onTapGesture {
                        isImporting = true
                    }
                    .fileImporter(
                        isPresented: $isImporting,
                        allowedContentTypes: [.commaSeparatedText],
                        allowsMultipleSelection: false
                    ) { result in
                        switch result {
                        case .success(let urls):
                            if let url = urls.first {
                                handleFileImport(url: url)
                            }
                        case .failure(let error):
                            importMessage = "导入失败: \(error.localizedDescription)"
                            showAlert = true
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // 下载模板按钮
                    HStack {
                        Spacer()
                        ShareLink(item: generateCSVTemplateURL(), preview: SharePreview("餐厅导入模板")) {
                            Text("下载导入模板 (.csv)")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    // 分割线
                    HStack {
                        Divider()
                        Text("或者粘贴文本")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 10)
                        Divider()
                    }
                    .padding(.horizontal, 20)
                    
                    // 文本区域
                    VStack(alignment: .leading, spacing: 10) {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $csvText)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .frame(minHeight: 200)
                            if csvText.isEmpty {
                                Text("粘贴 CSV 文本内容...")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 28)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
            
            // 底部按钮
            HStack(spacing: 15) {
                Button("取消") {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.black)
                .cornerRadius(12)
                
                Button("导入文本") {
                    importCSVText()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding()
            .overlay(
                Divider()
                    .frame(height: 1)
                    .background(.gray.opacity(0.2))
                    .padding(.bottom, 44)
            )
        }
        .alert(importMessage, isPresented: $showAlert) {
            Button("确定") {}
        }
    }
    
    // 生成CSV模板URL
    private func generateCSVTemplateURL() -> URL {
        let csvContent = "名称,菜系,区域,评分,地址,评价,标签\n示例餐厅,川菜,川菜馆,4,北京市朝阳区,味道不错,辣；好吃"
        let url = URL(filePath: NSTemporaryDirectory() + "餐厅导入模板.csv")
        try? csvContent.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    // 处理文件导入
    private func handleFileImport(url: URL) {
        importFromCSV(url: url)
    }
    
    // 导入CSV文件
    private func importFromCSV(url: URL) {
        // 安全访问外部文件
        guard url.startAccessingSecurityScopedResource() else {
            importMessage = "无法访问文件"
            showAlert = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            // 读取文件内容
            let content = try String(contentsOf: url, encoding: .utf8)
            processCSVContent(content)
        } catch {
            print("读取文件失败: \(error)")
            importMessage = "读取文件失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // 导入CSV文本
    private func importCSVText() {
        if csvText.isEmpty {
            importMessage = "请输入或粘贴CSV文本内容"
            showAlert = true
            return
        }
        
        processCSVContent(csvText)
    }
    
    // 处理CSV内容
    private func processCSVContent(_ content: String) {
        do {
            // 按换行符分割行
            var lines = content.components(separatedBy: .newlines)
            
            // 跳过表头行
            guard lines.count > 1 else {
                importMessage = "CSV文件格式错误，缺少数据行"
                showAlert = true
                return
            }
            lines.removeFirst()
            
            var importedCount = 0
            
            // 解析每一行
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                if trimmedLine.isEmpty {
                    continue
                }
                
                // 按逗号分割字段
                let fields = trimmedLine.components(separatedBy: ",")
                
                // 检查字段数量
                guard fields.count >= 7 else {
                    print("行格式错误: \(line)")
                    continue
                }
                
                // 解析字段
                let name = fields[0].trimmingCharacters(in: .whitespaces)
                let type = fields[1].trimmingCharacters(in: .whitespaces)
                let district = fields[2].trimmingCharacters(in: .whitespaces)
                let rating = Int(fields[3].trimmingCharacters(in: .whitespaces)) ?? 3
                let address = fields[4].trimmingCharacters(in: .whitespaces)
                let review = fields[5].trimmingCharacters(in: .whitespaces) + " (待定位)"
                let tags = fields[6].trimmingCharacters(in: .whitespaces).split(separator: " ").map { String($0) }
                
                // 创建Restaurant对象
                let restaurant = Restaurant(
                    name: name,
                    type: type,
                    district: district,
                    rating: rating,
                    address: address,
                    latitude: 0.0,
                    longitude: 0.0,
                    coverPhotoFilename: nil,
                    review: review,
                    tags: tags
                )
                
                // 保存到数据库
                modelContext.insert(restaurant)
                importedCount += 1
            }
            
            importMessage = "成功导入 \(importedCount) 家餐厅！"
            showAlert = true
            
        } catch {
            print("解析CSV失败: \(error)")
            importMessage = "解析CSV失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
}



