//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
import ARKit
import Combine
import CoreHaptics
import SwiftUI

/// AR资源协调器，负责管理LiDAR和摄像头资源的共享使用
@Observable
class ARResourceCoordinator: NSObject, ARSessionDelegate {

    /// 单例实例
    static let shared = ARResourceCoordinator()

    /// AR会话
    private var arSession: ARSession?

    /// AR配置
    private var arConfiguration: ARConfiguration?

    /// 是否已启动
    private(set) var isRunning = false

    /// 当前检测到的距离（米）
    private(set) var currentDistance: Float = 0

    /// 当前威胁等级
    private(set) var threatLevel: DistanceThreatLevel = .none

    /// 最近一次捕获的图像
    private(set) var latestCapturedImage: CVPixelBuffer?

    /// 最近一次捕获的深度图
    private(set) var latestDepthMap: CVPixelBuffer?

    /// 图像更新发布者
    let imageUpdatePublisher = PassthroughSubject<CVPixelBuffer, Never>()

    /// 深度更新发布者
    let depthUpdatePublisher = PassthroughSubject<(CVPixelBuffer, Float), Never>()

    /// 距离更新发布者
    let distanceUpdatePublisher = PassthroughSubject<(Float, DistanceThreatLevel), Never>()

    /// 是否启用LiDAR距离感知
    public var isLiDAREnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "lidarDistanceSensingEnabled")
        }
        set {
            // 如果状态没有变化，不做任何操作
            let oldValue = UserDefaults.standard.bool(forKey: "lidarDistanceSensingEnabled")
            if newValue == oldValue {
                return
            }

            UserDefaults.standard.set(newValue, forKey: "lidarDistanceSensingEnabled")

            if newValue {
                // 确保先停止任何可能存在的会话
                stopSession()
                // 延迟一小段时间再启动新会话，给系统时间释放资源
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.startSession()
                }
            } else {
                stopSession()
                // 停止振动反馈
                HapticFeedbackManager.shared.stopHapticFeedback()
            }
        }
    }

    /// 是否启用振动反馈
    public var hapticFeedbackEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "lidarHapticFeedbackEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lidarHapticFeedbackEnabled")
            if !newValue {
                // 停止振动反馈
                HapticFeedbackManager.shared.stopHapticFeedback()
            }
        }
    }

    /// 距离阈值设置（米）
    public var highThreatThreshold: Float {
        get {
            let value = UserDefaults.standard.float(forKey: "lidarHighThreatThreshold")
            return value > 0 ? value : 1.0 // 默认1米
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lidarHighThreatThreshold")
        }
    }

    public var mediumThreatThreshold: Float {
        get {
            let value = UserDefaults.standard.float(forKey: "lidarMediumThreatThreshold")
            return value > 0 ? value : 2.0 // 默认2米
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lidarMediumThreatThreshold")
        }
    }

    public var lowThreatThreshold: Float {
        get {
            let value = UserDefaults.standard.float(forKey: "lidarLowThreatThreshold")
            return value > 0 ? value : 5.0 // 默认5米
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lidarLowThreatThreshold")
        }
    }

    /// 初始化
    private override init() {
        super.init()

        // 设置默认值（如果尚未设置）
        if !UserDefaults.standard.bool(forKey: "lidarDistanceSettingsInitialized") {
            UserDefaults.standard.set(true, forKey: "lidarHapticFeedbackEnabled")
            UserDefaults.standard.set(1.0, forKey: "lidarHighThreatThreshold")
            UserDefaults.standard.set(2.0, forKey: "lidarMediumThreatThreshold")
            UserDefaults.standard.set(5.0, forKey: "lidarLowThreatThreshold")
            UserDefaults.standard.set(true, forKey: "lidarDistanceSettingsInitialized")
        }
    }

    /// 启动AR会话
    func startSession() {
        // 如果会话已经存在，先停止它
        if let existingSession = arSession {
            existingSession.pause()
            print("停止现有AR会话")
        }

        // 检查设备是否支持LiDAR
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            print("设备不支持LiDAR")
            return
        }

        // 创建AR会话
        let session = ARSession()
        session.delegate = self

        // 创建优化的AR配置
        let configuration = ARWorldTrackingConfiguration()

        // 请求深度数据和摄像头图像
        configuration.frameSemantics = [.sceneDepth]

        // 禁用不必要的功能，减少资源占用
        configuration.planeDetection = []
        configuration.environmentTexturing = .none
        if #available(iOS 13.4, *) {
            configuration.sceneReconstruction = []
        }

        // 使用较低分辨率
        if let lowestResFormat = ARWorldTrackingConfiguration.supportedVideoFormats
            .filter({ $0.imageResolution.width >= 960 }) // 确保至少有一定分辨率
            .min(by: { $0.imageResolution.width < $1.imageResolution.width }) {
            configuration.videoFormat = lowestResFormat
            print("使用优化的视频格式: \(lowestResFormat.imageResolution.width)x\(lowestResFormat.imageResolution.height)")
        }

        do {
            // 启动会话
            session.run(configuration, options: [.removeExistingAnchors])

            // 保存会话和配置
            arSession = session
            arConfiguration = configuration
            isRunning = true

            print("AR会话已启动 - 同时支持LiDAR和摄像头")
        } catch {
            print("启动AR会话失败: \(error.localizedDescription)")
        }
    }

    /// 停止AR会话
    func stopSession() {
        if let session = arSession {
            session.pause()
            print("AR会话已停止")
        }
        // 清除引用，释放资源
        arSession = nil
        arConfiguration = nil
        isRunning = false

        // 重置状态
        currentDistance = 0
        threatLevel = .none
        latestCapturedImage = nil
        latestDepthMap = nil
    }

    /// 重新启动AR会话
    func restartSession() {
        print("尝试重新启动AR会话...")
        stopSession()

        // 延迟一段时间后重新启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.isLiDAREnabled else { return }
            self.startSession()
        }
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // 1. 处理摄像头图像
        let capturedImage = frame.capturedImage
        latestCapturedImage = capturedImage
        imageUpdatePublisher.send(capturedImage)

        // 2. 处理深度数据
        guard let depthMap = frame.sceneDepth?.depthMap else {
            // 如果无法获取深度数据，设置距离为0
            if currentDistance > 0 {
                currentDistance = 0
                updateThreatLevel(for: 0)

                // 停止振动反馈
                if hapticFeedbackEnabled {
                    HapticFeedbackManager.shared.stopHapticFeedback()
                }
            }
            return
        }

        // 保存深度图
        latestDepthMap = depthMap

        // 3. 计算距离
        let distance = calculateFrontDistance(from: depthMap)

        // 如果距离无效（为0），可能是深度数据问题
        if distance <= 0 && currentDistance > 0 {
            // 保持当前距离不变，避免突然变化
            return
        }

        // 4. 更新当前距离
        currentDistance = distance

        // 5. 更新威胁等级
        updateThreatLevel(for: distance)

        // 6. 发布更新
        depthUpdatePublisher.send((depthMap, distance))
        distanceUpdatePublisher.send((distance, threatLevel))

        // 7. 如果启用了振动反馈，根据威胁等级提供反馈
        if hapticFeedbackEnabled {
            provideHapticFeedback(for: threatLevel)
        } else {
            // 确保停止振动反馈
            HapticFeedbackManager.shared.stopHapticFeedback()
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR会话失败: \(error.localizedDescription)")

        // 如果是资源冲突错误，尝试重新启动会话
        if (error as NSError).code == -12784 {
            print("检测到资源冲突，尝试重新启动AR会话")
            stopSession()

            // 延迟一段时间后重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startSession()
            }
        }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("AR会话被中断")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("AR会话中断结束，重置会话")

        // 会话中断结束后，重置会话
        if isLiDAREnabled {
            stopSession()
            startSession()
        }
    }

    // MARK: - 辅助方法

    /// 计算前方障碍物的距离
    private func calculateFrontDistance(from depthMap: CVPixelBuffer) -> Float {
        // 获取深度图的中心区域
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        // 定义中心区域的大小（使用中心30%的区域）
        let centerRegionWidth = Int(Float(width) * 0.3)
        let centerRegionHeight = Int(Float(height) * 0.3)
        let startX = (width - centerRegionWidth) / 2
        let startY = (height - centerRegionHeight) / 2

        // 锁定像素缓冲区
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        // 获取像素数据
        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)!
        let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)

        // 计算中心区域的平均深度
        var totalDepth: Float = 0
        var validPixels = 0

        for y in startY..<(startY + centerRegionHeight) {
            for x in startX..<(startX + centerRegionWidth) {
                let pixelAddress = baseAddress.advanced(by: y * bytesPerRow + x * MemoryLayout<Float32>.size)
                let depth = pixelAddress.assumingMemoryBound(to: Float32.self).pointee

                // 只考虑有效的深度值（大于0且小于10米）
                if depth > 0 && depth < 10 {
                    totalDepth += depth
                    validPixels += 1
                }
            }
        }

        // 计算平均深度
        let averageDepth = validPixels > 0 ? totalDepth / Float(validPixels) : 0

        return averageDepth
    }

    /// 更新威胁等级
    private func updateThreatLevel(for distance: Float) {
        if distance <= highThreatThreshold && distance > 0 {
            threatLevel = .high
        } else if distance <= mediumThreatThreshold && distance > highThreatThreshold {
            threatLevel = .medium
        } else if distance <= lowThreatThreshold && distance > mediumThreatThreshold {
            threatLevel = .low
        } else {
            threatLevel = .none
        }
    }

    /// 根据威胁等级提供振动反馈
    private func provideHapticFeedback(for threatLevel: DistanceThreatLevel) {
        // 确保距离在有效范围内
        if currentDistance <= 0 || currentDistance > lowThreatThreshold {
            // 如果距离超出范围，停止振动
            HapticFeedbackManager.shared.stopHapticFeedback()
            return
        }

        // 根据威胁等级和距离提供触觉反馈
        switch threatLevel {
        case .high, .medium, .low:
            // 有威胁 - 根据距离播放触觉反馈
            HapticFeedbackManager.shared.playHapticFeedback(forDistance: currentDistance)
        case .none:
            // 无威胁 - 停止振动
            HapticFeedbackManager.shared.stopHapticFeedback()
        }
    }
}
