//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
import CoreHaptics
import UIKit

/// 🎮 简化的触觉反馈管理器
/// 提供基于距离的20级触觉反馈强度
class HapticFeedbackManager: ObservableObject {

    /// 单例实例
    static let shared = HapticFeedbackManager()

    /// 触觉引擎
    private var engine: CHHapticEngine?

    /// 是否支持触觉反馈
    private var supportsHaptics: Bool = false

    /// 初始化
    private init() {
        setupHapticEngine()
    }

    /// 设置触觉引擎
    private func setupHapticEngine() {
        // 检查设备是否支持触觉反馈
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        supportsHaptics = capabilities.supportsHaptics
        
        guard supportsHaptics else {
            print("❌ 设备不支持触觉反馈")
            return
        }

        do {
            // 创建触觉引擎
            engine = try CHHapticEngine()
            
            // 设置引擎重置处理程序
            engine?.resetHandler = { [weak self] in
                print("🔄 触觉引擎重置")
                do {
                    try self?.engine?.start()
                } catch {
                    print("❌ 触觉引擎重启失败: \(error)")
                }
            }
            
            // 设置引擎停止处理程序
            engine?.stoppedHandler = { reason in
                print("⏹️ 触觉引擎停止，原因: \(reason)")
            }
            
            // 启动引擎
            try engine?.start()
            print("✅ 触觉引擎初始化成功")
            
        } catch {
            print("❌ 触觉引擎创建失败: \(error)")
            supportsHaptics = false
        }
    }

    /// 根据距离播放触觉反馈
    /// - Parameter distance: 距离值（0.1-5.0米）
    func playHapticFeedback(forDistance distance: Float) {
        guard supportsHaptics, let engine = engine else {
            print("❌ 触觉反馈不可用")
            return
        }
        
        // 验证距离范围
        guard distance > 0.1 && distance <= 5.0 else {
            print("❌ 距离超出范围: \(distance)米")
            return
        }
        
        // 计算触觉强度（20个等级）
        let intensity = calculateIntensity(for: distance)
        let sharpness = calculateSharpness(for: distance)
        
        do {
            // 确保引擎运行
            try engine.start()
            
            // 创建瞬时触觉事件
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                ],
                relativeTime: 0
            )
            
            // 创建触觉模式
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            
            // 播放触觉反馈
            try player.start(atTime: CHHapticTimeImmediate)
            
            print("🎮 触觉反馈 - 距离: \(String(format: "%.2f", distance))米, 强度: \(String(format: "%.2f", intensity))")
            
        } catch {
            print("❌ 播放触觉反馈失败: \(error)")
        }
    }

    /// 计算基于距离的触觉强度（20个等级）
    /// - Parameter distance: 距离值（0.1-5.0米）
    /// - Returns: 强度值（0.1-1.0）
    private func calculateIntensity(for distance: Float) -> Float {
        // 将距离映射到20个等级
        let normalizedDistance = (distance - 0.1) / (5.0 - 0.1) // 归一化到0-1
        let level = Int((1.0 - normalizedDistance) * 19) // 反向映射到0-19级
        let intensity = Float(level + 1) / 20.0 // 转换为0.05-1.0的强度
        
        return max(0.1, min(1.0, intensity))
    }

    /// 计算基于距离的触觉锐度
    /// - Parameter distance: 距离值（0.1-5.0米）
    /// - Returns: 锐度值（0.3-1.0）
    private func calculateSharpness(for distance: Float) -> Float {
        // 距离越近，锐度越高
        let normalizedDistance = (distance - 0.1) / (5.0 - 0.1)
        let sharpness = 0.3 + (1.0 - normalizedDistance) * 0.7
        
        return Float(sharpness)
    }

    /// 播放简单的触觉反馈（用于按钮点击等）
    func playSimpleHapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        print("🎮 简单触觉反馈已触发")
    }

    /// 停止所有触觉反馈
    func stopHapticFeedback() {
        // 对于瞬时触觉反馈，不需要特殊的停止操作
        print("🛑 触觉反馈已停止")
    }

    /// 测试触觉反馈功能
    func testHapticFeedback() {
        print("🧪 开始测试触觉反馈功能")
        
        guard supportsHaptics else {
            print("❌ 设备不支持触觉反馈")
            return
        }
        
        // 测试不同距离的触觉反馈
        let testDistances: [Float] = [0.2, 0.5, 1.0, 2.0, 3.0, 5.0]
        
        for (index, distance) in testDistances.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                print("🧪 测试距离: \(distance)米")
                self.playHapticFeedback(forDistance: distance)
            }
        }
        
        print("🧪 触觉反馈测试完成")
    }

    /// 获取触觉反馈等级描述
    /// - Parameter distance: 距离值
    /// - Returns: 等级描述
    func getHapticLevelDescription(for distance: Float) -> String {
        let intensity = calculateIntensity(for: distance)
        let level = Int(intensity * 20)
        
        switch level {
        case 17...20:
            return "极强振动 (等级\(level)/20)"
        case 13...16:
            return "强振动 (等级\(level)/20)"
        case 9...12:
            return "中等振动 (等级\(level)/20)"
        case 5...8:
            return "轻微振动 (等级\(level)/20)"
        default:
            return "微弱振动 (等级\(level)/20)"
        }
    }
}
