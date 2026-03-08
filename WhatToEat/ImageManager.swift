//
//  ImageManager.swift
//  WhatToEat
//
//  Created by 廖云丰 on 2026/1/17.
//

import Foundation
import UIKit

class ImageManager {
    // 单例实例
    static let shared = ImageManager()
    
    // 私有初始化
    private init() {}
    
    // 内存缓存，避免重复读取同一图片
    private var imageCache: [String: UIImage] = [:]
    
    // 获取Documents目录路径
    private var documentsDirectory: URL {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[0]
    }
    
    // 保存图片
    func saveImage(_ image: UIImage) -> String? {
        // 压缩图片为JPEG格式，质量0.6
        guard let imageData = image.jpegData(compressionQuality: 0.6) else {
            return nil
        }
        
        // 生成UUID文件名
        let filename = UUID().uuidString + ".jpg"
        
        // 创建文件路径
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        // 保存图片
        do {
            try imageData.write(to: fileURL)
            return filename
        } catch {
            AppLogger.error("保存图片失败: \(error.localizedDescription)", category: .storage)
            return nil
        }
    }
    
    // 异步读取图片
    func loadImageAsync(filename: String) async -> UIImage? {
        // 先检查缓存
        if let cachedImage = imageCache[filename] {
            return cachedImage
        }
        
        // 创建文件路径
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // 异步读取图片
        do {
            let imageData = try Data(contentsOf: fileURL)
            if let image = UIImage(data: imageData) {
                // 将图片加入缓存
                imageCache[filename] = image
                return image
            }
            return nil
        } catch {
            AppLogger.error("读取图片失败: \(error.localizedDescription)", category: .storage)
            return nil
        }
    }
    
    // 读取图片（同步版本，保持向后兼容）
    func loadImage(filename: String) -> UIImage? {
        // 先检查缓存
        if let cachedImage = imageCache[filename] {
            return cachedImage
        }
        
        // 创建文件路径
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // 读取图片
        do {
            let imageData = try Data(contentsOf: fileURL)
            if let image = UIImage(data: imageData) {
                // 将图片加入缓存
                imageCache[filename] = image
                return image
            }
            return nil
        } catch {
            AppLogger.error("读取图片失败: \(error.localizedDescription)", category: .storage)
            return nil
        }
    }
    
    // 删除图片
    func deleteImage(filename: String) {
        // 从缓存中移除
        imageCache.removeValue(forKey: filename)
        
        // 创建文件路径
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        // 删除文件
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            AppLogger.error("删除图片失败: \(error.localizedDescription)", category: .storage)
        }
    }
}
