//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Vision
import CoreImage
import AVFoundation

/// 图像相似度评估结果
public struct SimilarityResult {
    /// 相似度值（0-1，值越高表示越相似）
    let similarity: Double
    
    /// 是否应该处理新帧
    let shouldProcessNewFrame: Bool
    
    /// 是否是首帧
    let isFirstFrame: Bool
}

/// 使用Vision框架提取和比较图像特征的工具类
public class ImageSimilarityDetector {
    
    /// 单例实例
    public static let shared = ImageSimilarityDetector()
    
    /// 上一帧的特征向量
    private var lastFeaturePrint: VNFeaturePrintObservation?
    
    /// 上一次特征提取的时间戳
    private var lastFeatureTime: Date = Date.distantPast
    
    /// 最小特征提取间隔（秒）
    private var minFeatureInterval: TimeInterval = 0.5
    
    /// 相似度阈值（0-1之间，值越大表示需要更大差异才会触发新朗读）
    private var similarityThreshold: Double = 0.7
    
    /// 私有初始化方法
    private init() {}
    
    /// 配置参数
    /// - Parameters:
    ///   - minInterval: 最小特征提取间隔（秒）
    ///   - threshold: 相似度阈值（0-1）
    public func configure(minInterval: TimeInterval, threshold: Double) {
        self.minFeatureInterval = minInterval
        self.similarityThreshold = threshold
    }
    
    /// 重置检测器状态
    public func reset() {
        lastFeaturePrint = nil
        lastFeatureTime = Date.distantPast
    }
    
    /// 检测当前图像帧与上一帧的相似度
    /// - Parameter imageBuffer: 当前图像帧
    /// - Returns: 相似度评估结果，包含相似度值和是否应该处理新帧
    public func detectSimilarity(for imageBuffer: CVImageBuffer) async -> SimilarityResult {
        // 当前时间
        let now = Date()
        
        // 距离上次特征提取的时间间隔
        let timeSinceLastFeature = now.timeIntervalSince(lastFeatureTime)
        
        // 如果是首次处理或者已经过了足够长的时间
        if lastFeaturePrint == nil || timeSinceLastFeature >= minFeatureInterval {
            // 提取当前帧的特征
            if let currentFeaturePrint = try? await extractFeaturePrint(from: imageBuffer) {
                
                // 如果有上一帧的特征，计算相似度
                if let lastFeaturePrint = lastFeaturePrint {
                    var distance: Float = 0
                    try? lastFeaturePrint.computeDistance(&distance, to: currentFeaturePrint)
                    
                    // 将距离转换为相似度（距离越小，相似度越高）
                    let similarity = 1.0 - Double(distance)
                    
                    // 更新状态
                    self.lastFeaturePrint = currentFeaturePrint
                    self.lastFeatureTime = now
                    
                    // 决定是否应该处理新帧
                    let shouldProcess = similarity < similarityThreshold
                    
                    return SimilarityResult(
                        similarity: similarity,
                        shouldProcessNewFrame: shouldProcess,
                        isFirstFrame: false
                    )
                } else {
                    // 首次处理，保存特征并返回应该处理
                    self.lastFeaturePrint = currentFeaturePrint
                    self.lastFeatureTime = now
                    
                    return SimilarityResult(
                        similarity: 0,
                        shouldProcessNewFrame: true,
                        isFirstFrame: true
                    )
                }
            }
        }
        
        // 如果无法提取特征或者时间间隔太短，返回高相似度，不处理新帧
        return SimilarityResult(
            similarity: 1.0,
            shouldProcessNewFrame: false,
            isFirstFrame: false
        )
    }
    
    /// 从CVImageBuffer提取特征向量
    /// - Parameter imageBuffer: 图像缓冲区
    /// - Returns: 特征向量观察结果
    private func extractFeaturePrint(from imageBuffer: CVImageBuffer) async throws -> VNFeaturePrintObservation {
        // 创建CIImage
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        
        // 创建请求
        let request = VNGenerateImageFeaturePrintRequest()
        // 使用场景特征类型，对场景变化更敏感
        request.usesCPUOnly = false // 使用GPU加速
        
        // 创建处理请求的处理器
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        // 执行请求
        try handler.perform([request])
        
        // 获取结果
        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw NSError(domain: "ImageSimilarityDetector", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法提取图像特征"])
        }
        
        return observation
    }
}
