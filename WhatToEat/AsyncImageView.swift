import SwiftUI
import UIKit
import Combine

// MARK: - 1. 异步图片加载器
/// 管理异步图片加载状态的 ObservableObject
class AsyncImageLoader: ObservableObject {
    @Published var image: UIImage? = nil
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
    // 图片缓存（使用单例ImageCacheManager）
    
    // 取消标记
    private var cancellable: Bool = false
    
    // MARK: - 图片加载方法
    /// 加载图片，支持缓存和预解码
    /// - Parameters:
    ///   - filename: 图片文件名
    ///   - placeholder: 占位符图片
    func loadImage(filename: String, placeholder: UIImage? = nil) {
        // 重置状态
        cancellable = false
        isLoading = true
        error = nil
        
        // 1. 检查内存缓存
        if let cachedImage = ImageCacheManager.shared.getFromCache(forKey: filename) {
            self.image = cachedImage
            self.isLoading = false
            return
        }
        
        // 2. 使用占位符
        self.image = placeholder
        
        // 3. 在后台线程加载图片
        DispatchQueue.global().async {
            // 检查是否已取消
            guard !self.cancellable else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            // 4. 从磁盘加载图片
            guard let imageData = try? Data(contentsOf: AsyncImageLoader.getImageURL(for: filename)),
                  let originalImage = UIImage(data: imageData) else {
                DispatchQueue.main.async {
                    self.error = NSError(domain: "AsyncImageLoader", code: 1, userInfo: [NSLocalizedDescriptionKey: "图片加载失败"])
                    self.isLoading = false
                }
                return
            }

            // 4.5 修正图片方向
            let fixedImage = originalImage.fixOrientation()
            
            // 5. 检查是否已取消
            guard !self.cancellable else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            // 6. 预解码图片（优化渲染性能）
            AnimationUtils.preDecodeImage(fixedImage) { decodedImage in
                // 检查是否已取消
                guard !self.cancellable else {
                    self.isLoading = false
                    return
                }
                
                if let decodedImage = decodedImage {
                    // 7. 缓存解码后的图片
                    ImageCacheManager.shared.saveToCache(image: decodedImage, forKey: filename)
                    
                    // 8. 更新UI
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.image = decodedImage
                            self.isLoading = false
                        }
                    }
                } else {
                    // 解码失败，使用方向修正后的图片
                    ImageCacheManager.shared.saveToCache(image: fixedImage, forKey: filename)
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.image = fixedImage
                            self.isLoading = false
                        }
                    }
                }
            }
        }
    }
    
    /// 取消图片加载
    func cancel() {
        cancellable = true
    }
    
    /// 重置加载器状态
    func reset() {
        cancellable = false
        image = nil
        isLoading = false
        error = nil
    }
    
    /// 清除缓存
    static func clearCache() {
        ImageCacheManager.shared.clearCache()
    }
    
    /// 预加载多张图片
    /// - Parameters:
    ///   - filenames: 图片文件名数组
    ///   - completion: 预加载完成回调
    static func preloadImages(filenames: [String], completion: (() -> Void)? = nil) {
        guard !filenames.isEmpty else {
            completion?()
            return
        }
        
        let group = DispatchGroup()
        
        for filename in filenames {
            group.enter()
            
            DispatchQueue.global().async {
                // 加载并预解码图片
                if let imageData = try? Data(contentsOf: AsyncImageLoader.getImageURL(for: filename)),
                   let originalImage = UIImage(data: imageData) {
                    
                    // 预解码
                    AnimationUtils.preDecodeImage(originalImage) { decodedImage in
                        if let decodedImage = decodedImage {
                            // 缓存图片
                            ImageCacheManager.shared.saveToCache(image: decodedImage, forKey: filename)
                        }
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }
        }
        
        // 所有图片加载完成后调用回调
        group.notify(queue: .main) {
            completion?()
        }
    }
    
    /// 获取图片URL
    private static func getImageURL(for filename: String) -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(filename)
    }
}

// MARK: - 2. SwiftUI 异步图片视图
/// 异步加载图片的 SwiftUI 视图组件
struct AsyncImageView: View {
    private let filename: String?
    private let placeholder: AnyView?
    private let contentMode: ContentMode
    private let imageCacheKey: String?
    
    // 使用 StateObject 管理图片加载状态
    @StateObject private var loader = AsyncImageLoader()
    // 跟踪当前加载的文件名，用于检测变化
    @State private var loadedFilename: String?
    
    // MARK: - 初始化方法
    /// 初始化异步图片视图
    /// - Parameters:
    ///   - filename: 图片文件名
    ///   - placeholder: 占位符视图
    ///   - contentMode: 内容模式
    init(
        filename: String?, 
        placeholder: AnyView? = nil,
        contentMode: ContentMode = .fill
    ) {
        self.filename = filename
        self.placeholder = placeholder
        self.contentMode = contentMode
        self.imageCacheKey = filename
    }
    
    /// 初始化异步图片视图，使用系统图片作为占位符
    /// - Parameters:
    ///   - filename: 图片文件名
    ///   - systemPlaceholder: 系统图片名
    ///   - contentMode: 内容模式
    init(
        filename: String?, 
        systemPlaceholder: String,
        contentMode: ContentMode = .fill
    ) {
        self.filename = filename
        self.placeholder = AnyView(
            Image(systemName: systemPlaceholder)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .foregroundColor(.gray)
        )
        self.contentMode = contentMode
        self.imageCacheKey = filename
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                // 图片加载成功
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: loader.image)
            } else if loader.isLoading {
                // 加载中，显示占位符
                placeholder ?? AnyView(ProgressView())
            } else {
                // 加载失败或无图片，显示占位符
                placeholder ?? AnyView(
                    Image(systemName: "photo")
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .foregroundColor(.gray)
                )
            }
        }
        .onAppear {
            // 只在文件名变化或首次加载时重新加载
            if let filename = filename, filename != loadedFilename {
                loadedFilename = filename
                loader.loadImage(filename: filename)
            }
        }
        .onDisappear {
            // 视图消失时取消加载，避免内存泄漏
            loader.cancel()
        }
        .onChange(of: filename) { oldFilename, newFilename in
            // 文件名变化时重新加载
            if newFilename != loadedFilename {
                loadedFilename = newFilename
                loader.cancel()
                loader.reset()  // 重置加载器状态
                if let newFilename = newFilename {
                    loader.loadImage(filename: newFilename)
                }
            }
        }
    }
}

// MARK: - 3. 图片缓存管理
/// 图片缓存管理器，支持内存缓存和磁盘缓存
class ImageCacheManager {
    // 单例实例
    static let shared = ImageCacheManager()
    
    // 内存缓存
    private var memoryCache: [String: UIImage] = [:]
    
    // 内存缓存最大数量
    private let maxMemoryCacheSize = 100
    
    // 私有初始化
    private init() {}
    
    // MARK: - 缓存方法
    /// 保存图片到缓存
    /// - Parameters:
    ///   - image: 图片
    ///   - key: 缓存键
    func saveToCache(image: UIImage, forKey key: String) {
        // 1. 保存到内存缓存
        memoryCache[key] = image
        
        // 2. 管理缓存大小，超过限制则移除最早的缓存
        if memoryCache.count > maxMemoryCacheSize {
            let firstKey = memoryCache.keys.first
            if let key = firstKey {
                memoryCache.removeValue(forKey: key)
            }
        }
    }
    
    /// 从缓存获取图片
    /// - Parameter key: 缓存键
    /// - Returns: 缓存的图片，或 nil
    func getFromCache(forKey key: String) -> UIImage? {
        return memoryCache[key]
    }
    
    /// 清除所有缓存
    func clearCache() {
        memoryCache.removeAll()
    }
    
    /// 清除特定缓存
    /// - Parameter key: 缓存键
    func removeFromCache(forKey key: String) {
        memoryCache.removeValue(forKey: key)
    }
}

// MARK: - UIImage 方向修正扩展
extension UIImage {
    /// 修正图片方向，确保图片以正确的方向显示
    func fixOrientation() -> UIImage {
        // 如果图片方向已经是正常的，直接返回
        if imageOrientation == .up {
            return self
        }

        // 创建图形上下文来重新绘制图片
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }

        // 绘制图片（系统会自动处理方向转换）
        draw(in: CGRect(origin: .zero, size: size))

        // 获取修正后的图片
        guard let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            return self
        }

        return normalizedImage
    }
}
