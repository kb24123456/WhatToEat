import SwiftUI
import SpriteKit
import Combine

// MARK: - 1. SpriteKit 场景管理器
/// 管理 SpriteKit 场景的 ObservableObject
class SpriteKitSceneManager: ObservableObject {
    // MARK: - 场景类型
    enum SceneType {
        case particleEmitter
        case fireworks
        case confetti
        case custom(SKScene)
    }
    
    // MARK: - 属性
    /// 当前场景类型
    @Published var sceneType: SceneType
    
    /// SpriteKit 视图
    let skView: SKView
    
    /// 当前场景
    private(set) var currentScene: SKScene
    
    // MARK: - 初始化方法
    /// 初始化 SpriteKit 场景管理器
    /// - Parameter sceneType: 场景类型
    init(sceneType: SceneType = .particleEmitter) {
        self.sceneType = sceneType
        self.skView = SKView()
        
        // 创建初始场景
        switch sceneType {
        case .particleEmitter:
            currentScene = ParticleEmitterScene(size: CGSize(width: 400, height: 400))
        case .fireworks:
            currentScene = FireworksScene(size: CGSize(width: 400, height: 400))
        case .confetti:
            currentScene = ConfettiScene(size: CGSize(width: 400, height: 400))
        case .custom(let scene):
            currentScene = scene
        }
        
        // 配置 SKView
        configureSKView()
    }
    
    // MARK: - 配置方法
    /// 配置 SKView
    private func configureSKView() {
        enableHighPerformanceMode()
        
        // 启动场景
        skView.presentScene(currentScene)
    }
    
    /// 启用高性能配置
    func enableHighPerformanceMode() {
        skView.ignoresSiblingOrder = true
        skView.shouldCullNonVisibleNodes = true
        skView.isMultipleTouchEnabled = false
        skView.preferredFramesPerSecond = 60
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.showsPhysics = false
        skView.showsDrawCount = false
    }
    
    /// 启用调试配置
    func enableDebugMode() {
        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.showsPhysics = true
        skView.showsDrawCount = true
    }
    
    // MARK: - 公共方法
    /// 切换场景
    /// - Parameter sceneType: 新场景类型
    func switchScene(to sceneType: SceneType) {
        self.sceneType = sceneType
        
        // 创建新场景
        let newScene: SKScene
        switch sceneType {
        case .particleEmitter:
            newScene = ParticleEmitterScene(size: skView.bounds.size)
        case .fireworks:
            newScene = FireworksScene(size: skView.bounds.size)
        case .confetti:
            newScene = ConfettiScene(size: skView.bounds.size)
        case .custom(let scene):
            newScene = scene
        }
        
        // 平滑过渡到新场景
        skView.presentScene(newScene, transition: .crossFade(withDuration: 0.3))
        currentScene = newScene
    }
    
    /// 重置场景
    func resetScene() {
        switchScene(to: sceneType)
    }
    
    /// 暂停场景
    func pause() {
        skView.isPaused = true
    }
    
    /// 恢复场景
    func resume() {
        skView.isPaused = false
    }
    
    /// 调整场景大小
    /// - Parameter size: 新大小
    func resizeScene(to size: CGSize) {
        currentScene.size = size
    }
}

// MARK: - 2. SwiftUI SpriteKit 视图
/// SwiftUI 包装的 SpriteKit 视图
struct SpriteKitView: UIViewRepresentable {
    // MARK: - 属性
    /// 场景管理器
    @ObservedObject var sceneManager: SpriteKitSceneManager
    
    // MARK: - UIViewRepresentable 协议
    func makeUIView(context: Context) -> SKView {
        return sceneManager.skView
    }
    
    func updateUIView(_ uiView: SKView, context: Context) {
        // 确保场景大小与视图一致
        sceneManager.resizeScene(to: uiView.bounds.size)
    }
    
    // MARK: - 便捷初始化
    /// 创建粒子发射器场景
    init() {
        self.sceneManager = SpriteKitSceneManager(sceneType: .particleEmitter)
    }
    
    /// 创建指定类型的场景
    init(sceneType: SpriteKitSceneManager.SceneType) {
        self.sceneManager = SpriteKitSceneManager(sceneType: sceneType)
    }
    
    /// 使用自定义场景
    init(customScene: SKScene) {
        self.sceneManager = SpriteKitSceneManager(sceneType: .custom(customScene))
    }
}

// MARK: - 3. 粒子发射器场景
/// 基础粒子发射器场景
class ParticleEmitterScene: SKScene {
    // MARK: - 属性
    /// 粒子发射器
    private var particleEmitter: SKEmitterNode?
    
    // MARK: - 生命周期
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        // 设置背景颜色
        backgroundColor = .clear
        
        // 创建粒子发射器
        createParticleEmitter()
    }
    
    // MARK: - 粒子发射器创建
    /// 创建粒子发射器
    private func createParticleEmitter() {
        // 1. 创建粒子发射器
        let emitter = SKEmitterNode()
        
        // 2. 配置粒子属性
        emitter.particleTexture = SKTexture(imageNamed: "circle")
        emitter.particleBirthRate = 100
        emitter.particleLifetime = 2.0
        emitter.particleLifetimeRange = 0.5
        emitter.particlePosition = CGPoint(x: size.width / 2, y: size.height / 2)
        emitter.particlePositionRange = CGVector(dx: size.width / 2, dy: 0)
        emitter.particleSpeed = 100
        emitter.particleSpeedRange = 50
        emitter.particleSize = CGSize(width: 10, height: 10)
        // 移除不存在的属性
        emitter.particleColor = .red
        emitter.particleColorBlendFactor = 1.0
        emitter.particleColorSequence = nil
        emitter.particleAlpha = 1.0
        emitter.particleAlphaRange = 0.0
        emitter.particleAlphaSpeed = -0.5
        emitter.particleRotation = 0
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = 0
        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = .pi
        emitter.xAcceleration = 0
        emitter.yAcceleration = -100
        emitter.particleScale = 1.0
        emitter.particleScaleRange = 0.5
        emitter.particleScaleSpeed = -0.2
        emitter.particleBlendMode = .add
        emitter.zPosition = 1
        
        // 3. 优化内存使用
        optimizeEmitterMemoryUsage(emitter)
        
        // 4. 添加到场景
        addChild(emitter)
        particleEmitter = emitter
    }
    
    /// 优化粒子发射器内存使用
    private func optimizeEmitterMemoryUsage(_ emitter: SKEmitterNode) {
        // 限制粒子数量
        emitter.particleBirthRate = min(emitter.particleBirthRate, 200)
        emitter.particleLifetime = min(emitter.particleLifetime, 5.0)
        
        // 减少纹理大小
        if let texture = emitter.particleTexture {
            let maxTextureSize: CGFloat = 32
            if texture.size().width > maxTextureSize || texture.size().height > maxTextureSize {
                // 可以在这里缩放纹理
            }
        }
        
        // 减少粒子大小
        emitter.particleSize = CGSize(width: min(emitter.particleSize.width, 20), height: min(emitter.particleSize.height, 20))
    }
    
    // MARK: - 场景更新
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        // 可以在这里添加自定义更新逻辑
    }
}

// MARK: - 4. 烟花效果场景
/// 烟花效果场景
class FireworksScene: SKScene {
    // MARK: - 属性
    /// 烟花发射器数组
    private var fireworksEmitters: [SKEmitterNode] = []
    
    // MARK: - 生命周期
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        // 设置背景颜色
        backgroundColor = .clear
        
        // 定时发射烟花
        let launchTimer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(launchFirework), userInfo: nil, repeats: true)
        launchTimer.fire()
    }
    
    // MARK: - 烟花发射
    /// 发射烟花
    @objc private func launchFirework() {
        // 1. 创建烟花发射轨迹
        let trajectoryEmitter = SKEmitterNode()
        trajectoryEmitter.particleTexture = SKTexture(imageNamed: "circle")
        trajectoryEmitter.particleBirthRate = 20
        trajectoryEmitter.particleLifetime = 1.0
        trajectoryEmitter.particleLifetimeRange = 0.2
        trajectoryEmitter.particlePosition = CGPoint(x: CGFloat.random(in: 50...size.width - 50), y: 0)
        trajectoryEmitter.particleSpeed = 300
        trajectoryEmitter.particleSpeedRange = 50
        trajectoryEmitter.emissionAngle = .pi / 2
        trajectoryEmitter.emissionAngleRange = .pi / 6
        trajectoryEmitter.yAcceleration = -200
        trajectoryEmitter.particleColor = SKColor(red: CGFloat.random(in: 0.5...1.0), green: CGFloat.random(in: 0...0.5), blue: CGFloat.random(in: 0...0.5), alpha: 1.0)
        trajectoryEmitter.particleAlpha = 1.0
        trajectoryEmitter.particleAlphaSpeed = -0.5
        trajectoryEmitter.particleSize = CGSize(width: 4, height: 4)
        trajectoryEmitter.particleScale = 1.0
        trajectoryEmitter.particleScaleSpeed = -0.2
        trajectoryEmitter.particleBlendMode = .add
        
        // 2. 添加到场景
        addChild(trajectoryEmitter)
        fireworksEmitters.append(trajectoryEmitter)
        
        // 3. 一段时间后爆炸
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.createExplosion(at: CGPoint(x: trajectoryEmitter.particlePosition.x, y: self.size.height / 2 + CGFloat.random(in: -50...50)))
            trajectoryEmitter.removeFromParent()
            if let index = self.fireworksEmitters.firstIndex(of: trajectoryEmitter) {
                self.fireworksEmitters.remove(at: index)
            }
        }
    }
    
    /// 创建爆炸效果
    private func createExplosion(at position: CGPoint) {
        // 1. 创建爆炸粒子发射器
        let explosionEmitter = SKEmitterNode()
        explosionEmitter.particleTexture = SKTexture(imageNamed: "circle")
        explosionEmitter.particleBirthRate = 500
        explosionEmitter.particleLifetime = 2.0
        explosionEmitter.particleLifetimeRange = 0.5
        explosionEmitter.particlePosition = position
        explosionEmitter.particleSpeed = 150
        explosionEmitter.particleSpeedRange = 50
        explosionEmitter.emissionAngle = 0
        explosionEmitter.emissionAngleRange = .pi * 2
        explosionEmitter.xAcceleration = 0
        explosionEmitter.yAcceleration = -100
        
        // 随机颜色
        let randomColor = SKColor(red: CGFloat.random(in: 0.5...1.0), green: CGFloat.random(in: 0...0.5), blue: CGFloat.random(in: 0...0.5), alpha: 1.0)
        explosionEmitter.particleColor = randomColor
        explosionEmitter.particleColorBlendFactor = 1.0
        
        explosionEmitter.particleAlpha = 1.0
        explosionEmitter.particleAlphaSpeed = -0.5
        explosionEmitter.particleSize = CGSize(width: 6, height: 6)
        // 移除不存在的属性
        explosionEmitter.particleScale = 1.0
        explosionEmitter.particleScaleRange = 0.5
        explosionEmitter.particleScaleSpeed = -0.3
        explosionEmitter.particleBlendMode = .add
        
        // 2. 添加到场景
        addChild(explosionEmitter)
        fireworksEmitters.append(explosionEmitter)
        
        // 3. 一段时间后移除
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            explosionEmitter.removeFromParent()
            if let index = self.fireworksEmitters.firstIndex(of: explosionEmitter) {
                self.fireworksEmitters.remove(at: index)
            }
        }
    }
}

// MARK: - 5. 彩带效果场景
/// 彩带效果场景
class ConfettiScene: SKScene {
    // MARK: - 属性
    /// 彩带发射器
    private var confettiEmitter: SKEmitterNode?
    
    // MARK: - 生命周期
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        // 设置背景颜色
        backgroundColor = .clear
        
        // 创建彩带发射器
        createConfettiEmitter()
    }
    
    // MARK: - 彩带发射器创建
    /// 创建彩带发射器
    private func createConfettiEmitter() {
        // 1. 创建粒子发射器
        let emitter = SKEmitterNode()
        
        // 2. 配置粒子属性
        emitter.particleTexture = SKTexture(imageNamed: "square")
        emitter.particleBirthRate = 150
        emitter.particleLifetime = 3.0
        emitter.particleLifetimeRange = 1.0
        emitter.particlePosition = CGPoint(x: size.width / 2, y: size.height)
        emitter.particlePositionRange = CGVector(dx: size.width, dy: 0)
        emitter.particleSpeed = 100
        emitter.particleSpeedRange = 50
        // 移除不存在的属性
        emitter.emissionAngle = .pi
        emitter.emissionAngleRange = .pi / 3
        emitter.xAcceleration = 0
        emitter.yAcceleration = -50
        emitter.particleRotation = 0
        emitter.particleRotationRange = .pi * 2
        emitter.particleRotationSpeed = .pi / 2
        // 移除不存在的属性
        
        // 随机颜色
        let colors = [SKColor.red, SKColor.blue, SKColor.green, SKColor.yellow, SKColor.purple, SKColor.orange]
        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: colors, times: [0, 0.2, 0.4, 0.6, 0.8, 1.0])
        
        emitter.particleAlpha = 1.0
        emitter.particleAlphaSpeed = -0.3
        emitter.particleScale = 1.0
        emitter.particleScaleRange = 0.5
        emitter.particleScaleSpeed = -0.1
        emitter.particleBlendMode = .alpha
        
        // 3. 添加到场景
        addChild(emitter)
        confettiEmitter = emitter
    }
}

// MARK: - 6. 自定义粒子纹理
/// 自定义粒子纹理生成器
class ParticleTextureGenerator {
    /// 生成圆形纹理
    static func generateCircleTexture(radius: CGFloat, color: UIColor = .red) -> SKTexture {
        let size = CGSize(width: radius * 2, height: radius * 2)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: CGRect(origin: .zero, size: size))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        return SKTexture(image: image)
    }
    
    /// 生成方形纹理
    static func generateSquareTexture(size: CGFloat, color: UIColor = .red) -> SKTexture {
        let textureSize = CGSize(width: size, height: size)
        UIGraphicsBeginImageContextWithOptions(textureSize, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(origin: .zero, size: textureSize))
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        return SKTexture(image: image)
    }
    
    /// 生成星形纹理
    static func generateStarTexture(radius: CGFloat, color: UIColor = .red) -> SKTexture {
        let size = CGSize(width: radius * 2, height: radius * 2)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        let path = UIBezierPath()
        
        // 绘制星形
        let center = CGPoint(x: radius, y: radius)
        let numberOfPoints = 5
        let outerRadius = radius
        let innerRadius = radius * 0.4
        
        for i in 0...numberOfPoints {
            let angle = CGFloat(i) / CGFloat(numberOfPoints) * .pi * 2 - .pi / 2
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        
        path.close()
        context.setFillColor(color.cgColor)
        path.fill()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        return SKTexture(image: image)
    }
}


