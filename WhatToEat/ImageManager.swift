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
            print("保存图片失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 读取图片
    func loadImage(filename: String) -> UIImage? {
        // 创建文件路径
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        // 检查文件是否存在
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // 读取图片
        do {
            let imageData = try Data(contentsOf: fileURL)
            return UIImage(data: imageData)
        } catch {
            print("读取图片失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    // 删除图片
    func deleteImage(filename: String) {
        // 创建文件路径
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        // 删除文件
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("删除图片失败: \(error.localizedDescription)")
        }
    }
}
