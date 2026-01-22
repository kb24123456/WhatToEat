import UIKit
import QuartzCore

// MARK: - 1. 通用动画工具类
/// 提供动画优化的通用工具方法
class AnimationUtils {
    
    // MARK: - CALayer 动画封装
    /// 封装 CALayer 基础动画，避免直接使用 UIView.animate
    /// - Parameters:
    ///   - layer: 目标 CALayer
    ///   - keyPath: 动画属性路径
    ///   - fromValue: 起始值
    ///   - toValue: 结束值
    ///   - duration: 动画时长
    ///   - timingFunction: 缓动曲线
    ///   - repeatCount: 重复次数
    ///   - autoreverses: 是否自动反转
    ///   - completion: 完成回调
    static func animateLayer(
        _ layer: CALayer,
        keyPath: String,
        fromValue: Any? = nil,
        toValue: Any,
        duration: CFTimeInterval,
        timingFunction: CAMediaTimingFunctionName = .easeInEaseOut,
        repeatCount: Float = 0,
        autoreverses: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        // 取消当前正在进行的相同 keyPath 动画
        layer.removeAnimation(forKey: keyPath)
        
        // 创建基础动画
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = fromValue
        animation.toValue = toValue
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: timingFunction)
        animation.repeatCount = repeatCount
        animation.autoreverses = autoreverses
        
        // 设置完成回调
        if let completion = completion {
            animation.delegate = AnimationCompletionDelegate(completion: completion)
        }
        
        // 提交动画
        layer.add(animation, forKey: keyPath)
        
        // 立即更新 layer 属性，避免动画结束后回弹
        layer.setValue(toValue, forKeyPath: keyPath)
    }
    
    /// 封装 CALayer 弹簧动画
    /// - Parameters:
    ///   - layer: 目标 CALayer
    ///   - keyPath: 动画属性路径
    ///   - fromValue: 起始值
    ///   - toValue: 结束值
    ///   - duration: 动画时长
    ///   - damping: 阻尼系数 (0.0 - 1.0，值越小弹性越大)
    ///   - stiffness: 刚度系数 (值越大动画越硬)
    ///   - mass: 质量 (值越大动画越慢)
    ///   - completion: 完成回调
    static func animateLayerSpring(
        _ layer: CALayer,
        keyPath: String,
        fromValue: Any? = nil,
        toValue: Any,
        duration: CFTimeInterval,
        damping: CGFloat = 0.7,
        stiffness: CGFloat = 300,
        mass: CGFloat = 1,
        completion: (() -> Void)? = nil
    ) {
        // 取消当前正在进行的相同 keyPath 动画
        layer.removeAnimation(forKey: keyPath)
        
        // 创建弹簧动画
        let animation = CASpringAnimation(keyPath: keyPath)
        animation.fromValue = fromValue
        animation.toValue = toValue
        animation.duration = duration
        animation.damping = damping
        animation.stiffness = stiffness
        animation.mass = mass
        
        // 设置完成回调
        if let completion = completion {
            animation.delegate = AnimationCompletionDelegate(completion: completion)
        }
        
        // 提交动画
        layer.add(animation, forKey: keyPath)
        
        // 立即更新 layer 属性，避免动画结束后回弹
        layer.setValue(toValue, forKeyPath: keyPath)
    }
    
    // MARK: - 2. 主线程隔离工具
    /// 执行动画回调，并将耗时操作迁移到子线程
    /// - Parameters:
    ///   - animationBlock: 动画执行块（在主线程执行）
    ///   - backgroundWork: 耗时操作（在子线程执行）
    ///   - mainThreadCompletion: 主线程完成回调
    static func runAnimationWithBackgroundWork(
        animationBlock: @escaping () -> Void,
        backgroundWork: @escaping () -> Void,
        mainThreadCompletion: @escaping () -> Void
    ) {
        // 1. 在主线程执行动画
        DispatchQueue.main.async {
            animationBlock()
            
            // 2. 在后台线程执行耗时操作
            DispatchQueue.global().async {
                backgroundWork()
                
                // 3. 回到主线程执行完成回调
                DispatchQueue.main.async {
                    mainThreadCompletion()
                }
            }
        }
    }
    
    /// 优化带圆角和阴影的视图，避免离屏渲染
    /// - Parameters:
    ///   - view: 目标视图
    ///   - cornerRadius: 圆角半径
    ///   - shadowColor: 阴影颜色
    ///   - shadowOffset: 阴影偏移
    ///   - shadowOpacity: 阴影透明度
    ///   - shadowRadius: 阴影半径
    static func optimizeRoundedShadowView(
        _ view: UIView,
        cornerRadius: CGFloat,
        shadowColor: UIColor,
        shadowOffset: CGSize,
        shadowOpacity: Float,
        shadowRadius: CGFloat
    ) {
        // 1. 关闭光栅化（避免不必要的离屏渲染）
        view.layer.shouldRasterize = false
        
        // 2. 设置圆角
        view.layer.cornerRadius = cornerRadius
        
        // 3. 设置阴影路径（关键优化：避免模糊计算整个视图）
        view.layer.shadowPath = UIBezierPath(
            roundedRect: view.bounds,
            cornerRadius: cornerRadius
        ).cgPath
        view.layer.shadowColor = shadowColor.cgColor
        view.layer.shadowOffset = shadowOffset
        view.layer.shadowOpacity = shadowOpacity
        view.layer.shadowRadius = shadowRadius
        
        // 4. 确保视图不透明（减少混合计算）
        view.isOpaque = true
        view.backgroundColor = view.backgroundColor ?? .white
    }
    
    // MARK: - 5. 图片预解码
    /// 在后台线程预解码图片，避免主线程卡顿
    /// - Parameters:
    ///   - image: 原始图片
    ///   - completion: 解码完成回调
    static func preDecodeImage(
        _ image: UIImage,
        completion: @escaping (UIImage?) -> Void
    ) {
        DispatchQueue.global().async {
            // 创建位图上下文进行预解码
            guard let cgImage = image.cgImage else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let width = cgImage.width
            let height = cgImage.height
            let bitsPerComponent = 8
            let bytesPerRow = width * 4
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
            
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 绘制图片到上下文，完成预解码
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            // 获取解码后的图片
            guard let decodedCGImage = context.makeImage() else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let decodedImage = UIImage(cgImage: decodedCGImage)
            
            // 回到主线程返回结果
            DispatchQueue.main.async {
                completion(decodedImage)
            }
        }
    }
}

// MARK: - 动画完成回调代理
/// 处理 CALayer 动画的完成回调
class AnimationCompletionDelegate: NSObject, CAAnimationDelegate {
    private let completion: () -> Void
    
    init(completion: @escaping () -> Void) {
        self.completion = completion
        super.init()
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if flag {
            completion()
        }
    }
}

// MARK: - UIView 扩展
/// 为 UIView 添加动画优化扩展
extension UIView {
    /// 获取视图对应的 CALayer
    var layerAnimation: CALayer {
        return self.layer
    }
    
    /// 使用 CALayer 动画执行缩放
    /// - Parameters:
    ///   - scale: 缩放比例
    ///   - duration: 动画时长
    ///   - completion: 完成回调
    func scaleWithLayerAnimation(
        to scale: CGFloat,
        duration: CFTimeInterval,
        completion: (() -> Void)? = nil
    ) {
        AnimationUtils.animateLayer(
            self.layer,
            keyPath: "transform.scale",
            toValue: scale,
            duration: duration,
            completion: completion
        )
    }
    
    /// 使用 CALayer 动画执行平移
    /// - Parameters:
    ///   - translation: 平移距离
    ///   - duration: 动画时长
    ///   - completion: 完成回调
    func translateWithLayerAnimation(
        to translation: CGPoint,
        duration: CFTimeInterval,
        completion: (() -> Void)? = nil
    ) {
        let transform = CATransform3DMakeTranslation(translation.x, translation.y, 0)
        AnimationUtils.animateLayer(
            self.layer,
            keyPath: "transform",
            toValue: transform,
            duration: duration,
            completion: completion
        )
    }
    
    /// 使用 CALayer 动画执行透明度变化
    /// - Parameters:
    ///   - opacity: 透明度
    ///   - duration: 动画时长
    ///   - completion: 完成回调
    func fadeWithLayerAnimation(
        to opacity: CGFloat,
        duration: CFTimeInterval,
        completion: (() -> Void)? = nil
    ) {
        AnimationUtils.animateLayer(
            self.layer,
            keyPath: "opacity",
            toValue: opacity,
            duration: duration,
            completion: completion
        )
    }
    
    /// 使用 CALayer 弹簧动画执行缩放
    /// - Parameters:
    ///   - scale: 缩放比例
    ///   - duration: 动画时长
    ///   - damping: 阻尼系数
    ///   - completion: 完成回调
    func scaleWithSpringAnimation(
        to scale: CGFloat,
        duration: CFTimeInterval,
        damping: CGFloat = 0.7,
        completion: (() -> Void)? = nil
    ) {
        AnimationUtils.animateLayerSpring(
            self.layer,
            keyPath: "transform.scale",
            toValue: scale,
            duration: duration,
            damping: damping,
            completion: completion
        )
    }
}
