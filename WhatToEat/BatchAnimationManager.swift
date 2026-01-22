import Foundation
import UIKit
import SwiftUI

// MARK: - 1. 分批动画管理器
/// 控制动画并发执行，避免一次性触发大量动画导致掉帧
class BatchAnimationManager {
    // MARK: - 配置参数
    struct Configuration {
        /// 每批次动画数量
        let batchSize: Int
        /// 批次间延迟时间（秒）
        let batchDelay: TimeInterval
        /// 是否在主线程执行动画
        let executeOnMainThread: Bool
        
        /// 默认配置
        static let `default` = Configuration(batchSize: 10, batchDelay: 0.05, executeOnMainThread: true)
        
        /// 高性能配置（适合复杂动画）
        static let highPerformance = Configuration(batchSize: 5, batchDelay: 0.1, executeOnMainThread: true)
        
        /// 快速配置（适合简单动画）
        static let fast = Configuration(batchSize: 20, batchDelay: 0.02, executeOnMainThread: true)
    }
    
    // MARK: - 动画任务
    /// 动画任务闭包
    typealias AnimationTask = () -> Void
    
    // MARK: - 属性
    /// 配置
    private let config: Configuration
    
    /// 任务队列
    private var taskQueue: [AnimationTask] = []
    
    /// 当前是否正在执行动画
    private var isExecuting: Bool = false
    
    /// 取消标记
    private var isCancelled: Bool = false
    
    // MARK: - 初始化方法
    /// 初始化分批动画管理器
    /// - Parameter config: 配置参数
    init(config: Configuration = .default) {
        self.config = config
    }
    
    // MARK: - 公共方法
    /// 添加单个动画任务
    /// - Parameter task: 动画任务
    func addAnimation(_ task: @escaping AnimationTask) {
        taskQueue.append(task)
    }
    
    /// 添加多个动画任务
    /// - Parameter tasks: 动画任务数组
    func addAnimations(_ tasks: [AnimationTask]) {
        taskQueue.append(contentsOf: tasks)
    }
    
    /// 开始执行动画任务
    /// - Parameter completion: 所有动画完成回调
    func start(completion: (() -> Void)? = nil) {
        guard !isExecuting && !taskQueue.isEmpty else {
            completion?()
            return
        }
        
        isExecuting = true
        isCancelled = false
        
        // 执行动画批次
        executeNextBatch(completion: completion)
    }
    
    /// 取消所有动画任务
    func cancel() {
        isCancelled = true
        taskQueue.removeAll()
        isExecuting = false
    }
    
    /// 清空所有未执行的动画任务
    func clear() {
        taskQueue.removeAll()
    }
    
    // MARK: - 私有方法
    /// 执行下一批动画
    /// - Parameter completion: 所有动画完成回调
    private func executeNextBatch(completion: (() -> Void)? = nil) {
        guard !isCancelled && !taskQueue.isEmpty else {
            isExecuting = false
            completion?()
            return
        }
        
        // 1. 获取当前批次的任务
        let currentBatchSize = min(config.batchSize, taskQueue.count)
        let currentBatch = Array(taskQueue.prefix(currentBatchSize))
        taskQueue.removeFirst(currentBatchSize)
        
        // 2. 执行当前批次的动画
        executeBatch(currentBatch) {
            // 3. 延迟执行下一批
            DispatchQueue.main.asyncAfter(deadline: .now() + self.config.batchDelay) {
                self.executeNextBatch(completion: completion)
            }
        }
    }
    
    /// 执行单个批次的动画
    /// - Parameters:
    ///   - batch: 动画任务数组
    ///   - completion: 批次完成回调
    private func executeBatch(_ batch: [AnimationTask], completion: @escaping () -> Void) {
        guard !batch.isEmpty else {
            completion()
            return
        }
        
        let group = DispatchGroup()
        
        for task in batch {
            group.enter()
            
            if config.executeOnMainThread {
                // 在主线程执行动画
                DispatchQueue.main.async {
                    task()
                    group.leave()
                }
            } else {
                // 在后台线程执行动画（适合动画计算，不适合UI更新）
                DispatchQueue.global().async {
                    task()
                    group.leave()
                }
            }
        }
        
        // 当前批次所有动画完成后调用回调
        group.notify(queue: .main) {
            completion()
        }
    }
}

// MARK: - 2. 列表动画扩展
/// 为 Array 添加分批动画扩展
extension Array {
    /// 分批执行动画
    /// - Parameters:
    ///   - config: 分批配置
    ///   - animation: 动画闭包
    ///   - completion: 所有动画完成回调
    func forEachWithBatchAnimation(
        config: BatchAnimationManager.Configuration = .default,
        animation: @escaping (Element, Int) -> Void,
        completion: (() -> Void)? = nil
    ) {
        let manager = BatchAnimationManager(config: config)
        
        // 添加所有动画任务
        for (index, element) in self.enumerated() {
            manager.addAnimation {
                animation(element, index)
            }
        }
        
        // 开始执行
        manager.start(completion: completion)
    }
    
    /// 分批执行动画（简化版）
    /// - Parameters:
    ///   - batchSize: 每批次数量
    ///   - delay: 批次间延迟
    ///   - animation: 动画闭包
    ///   - completion: 所有动画完成回调
    func forEachWithBatchAnimation(
        batchSize: Int = 10,
        delay: TimeInterval = 0.05,
        animation: @escaping (Element, Int) -> Void,
        completion: (() -> Void)? = nil
    ) {
        let config = BatchAnimationManager.Configuration(
            batchSize: batchSize,
            batchDelay: delay,
            executeOnMainThread: true
        )
        
        forEachWithBatchAnimation(config: config, animation: animation, completion: completion)
    }
}



// MARK: - 4. 动画节流器
/// 动画节流器，避免短时间内重复触发相同动画
class AnimationThrottler {
    /// 节流时间间隔
    private let interval: TimeInterval
    
    /// 上次执行时间
    private var lastExecutionTime: Date = Date.distantPast
    
    /// 执行队列
    private let queue: DispatchQueue
    
    /// 初始化节流器
    /// - Parameters:
    ///   - interval: 节流时间间隔（秒）
    ///   - queue: 执行队列
    init(interval: TimeInterval, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }
    
    /// 执行节流
    /// - Parameter action: 要执行的操作
    func throttle(_ action: @escaping () -> Void) {
        let now = Date()
        let timeSinceLastExecution = now.timeIntervalSince(lastExecutionTime)
        
        if timeSinceLastExecution >= interval {
            // 立即执行
            lastExecutionTime = now
            queue.async {
                action()
            }
        } else {
            // 计算延迟时间
            let delay = interval - timeSinceLastExecution
            
            // 延迟执行
            queue.asyncAfter(deadline: .now() + delay) {
                // 再次检查时间间隔，避免重复执行
                let currentTime = Date()
                if currentTime.timeIntervalSince(self.lastExecutionTime) >= self.interval {
                    self.lastExecutionTime = currentTime
                    action()
                }
            }
        }
    }
}

// MARK: - 5. 动画防抖器
/// 动画防抖器，延迟执行，若在延迟期间再次触发则重新计时
class AnimationDebouncer {
    /// 防抖时间间隔
    private let interval: TimeInterval
    
    /// 执行队列
    private let queue: DispatchQueue
    
    /// 定时器
    private var timer: DispatchWorkItem?
    
    /// 初始化防抖器
    /// - Parameters:
    ///   - interval: 防抖时间间隔（秒）
    ///   - queue: 执行队列
    init(interval: TimeInterval, queue: DispatchQueue = .main) {
        self.interval = interval
        self.queue = queue
    }
    
    /// 执行防抖
    /// - Parameter action: 要执行的操作
    func debounce(_ action: @escaping () -> Void) {
        // 取消当前定时器
        timer?.cancel()
        
        // 创建新的定时器
        let newTimer = DispatchWorkItem {
            action()
        }
        
        // 保存定时器
        timer = newTimer
        
        // 延迟执行
        queue.asyncAfter(deadline: .now() + interval, execute: newTimer)
    }
    
    /// 取消当前防抖
    func cancel() {
        timer?.cancel()
        timer = nil
    }
}

// MARK: - 6. 动画协调器
/// 协调多个动画的执行，确保动画同步或按顺序执行
class AnimationCoordinator {
    // MARK: - 动画状态
    enum AnimationState {
        case idle
        case running
        case completed
        case cancelled
    }
    
    // MARK: - 属性
    /// 当前动画状态
    private(set) var state: AnimationState = .idle
    
    /// 动画完成回调
    private var completion: (() -> Void)? = nil
    
    /// 执行中的动画数量
    private var runningAnimations: Int = 0
    
    // MARK: - 公共方法
    /// 开始协调动画
    /// - Parameter completion: 所有动画完成回调
    func start(completion: (() -> Void)? = nil) {
        guard state == .idle else {
            return
        }
        
        state = .running
        self.completion = completion
        runningAnimations = 0
    }
    
    /// 注册一个动画任务
    /// - Parameter task: 动画任务闭包
    func registerAnimation(_ task: @escaping () -> Void) {
        guard state == .running else {
            return
        }
        
        // 增加执行中的动画数量
        runningAnimations += 1
        
        // 执行动画
        task()
    }
    
    /// 标记一个动画完成
    func markAnimationCompleted() {
        guard state == .running else {
            return
        }
        
        // 减少执行中的动画数量
        runningAnimations -= 1
        
        // 检查是否所有动画都已完成
        if runningAnimations <= 0 {
            state = .completed
            completion?()
        }
    }
    
    /// 取消所有动画
    func cancel() {
        state = .cancelled
        runningAnimations = 0
        completion?()
    }
    
    // MARK: - 便捷方法
    /// 执行一组动画并等待所有动画完成
    /// - Parameters:
    ///   - animations: 动画闭包数组
    ///   - completion: 所有动画完成回调
    func runAnimations(
        _ animations: [() -> Void],
        completion: (() -> Void)? = nil
    ) {
        start(completion: completion)
        
        for animation in animations {
            registerAnimation {
                animation()
                self.markAnimationCompleted()
            }
        }
    }
}


