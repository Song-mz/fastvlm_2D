//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
import ARKit
import Combine
import CoreHaptics
import SwiftUI
import Video

/// 距离威胁等级
public enum DistanceThreatLevel: Int, CaseIterable, Identifiable {
    case none = 0      // 无威胁
    case low = 1       // 低威胁（远距离）
    case medium = 2    // 中等威胁（中距离）
    case high = 3      // 高威胁（近距离）

    public var id: Int { rawValue }

    /// 获取威胁等级对应的描述
    var description: String {
        switch self {
        case .none:
            return "安全"
        case .low:
            return "注意"
        case .medium:
            return "警告"
        case .high:
            return "危险"
        }
    }

    /// 获取威胁等级对应的颜色
    var color: Color {
        switch self {
        case .none:
            return .green
        case .low:
            return .yellow
        case .medium:
            return .orange
        case .high:
            return .red
        }
    }
}

/// LiDAR距离传感器类，负责使用ARKit获取深度数据并计算距离
@Observable
class LiDARDistanceSensor: NSObject, ARSessionDelegate {

    /// 单例实例
    static let shared = LiDARDistanceSensor()

    /// AR会话
    private var arSession: ARSession?

    /// AR配置
    private var arConfiguration: ARConfiguration?

    /// 是否启用LiDAR距离感知（主开关）
    public var isEnabled: Bool {
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
                // 🔥 开启LiDAR时，自动开启所有相关功能
                print("🚀 开启LiDAR距离感知，自动启用所有相关功能")

                // 自动开启所有子功能（直接设置UserDefaults确保UI同步）
                UserDefaults.standard.set(true, forKey: "lidarHapticFeedbackEnabled")
                UserDefaults.standard.set(true, forKey: "lidarVoiceDistanceEnabled")
                UserDefaults.standard.set(true, forKey: "lidarCameraControlEnabled")

                // 根据摄像头控制设置决定是否停止摄像头
                if cameraControlEnabled {
                    if let camera = cameraController, camera.isRunning {
                        camera.stop()
                        cameraStoppedByLiDAR = true
                        print("📷 摄像头已停止以启用LiDAR距离感知")
                    }
                }

                // 确保先停止任何可能存在的会话
                stopSession()
                // 延迟一小段时间再启动新会话，给系统时间释放资源
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.startSession()
                }

                print("✅ LiDAR距离感知及所有相关功能已启用")
            } else {
                // 🔥 关闭LiDAR时，自动关闭所有相关功能并重置状态
                print("🛑 关闭LiDAR距离感知，重置所有相关功能")

                // 停止LiDAR会话
                stopSession()

                // 停止所有反馈
                HapticFeedbackManager.shared.stopHapticFeedback()
                stopVoiceAnnouncement()

                // 自动关闭所有子功能（直接设置UserDefaults确保UI同步）
                UserDefaults.standard.set(false, forKey: "lidarHapticFeedbackEnabled")
                UserDefaults.standard.set(false, forKey: "lidarVoiceDistanceEnabled")
                UserDefaults.standard.set(false, forKey: "lidarCameraControlEnabled")

                // 重置距离和威胁等级
                currentDistance = 0
                threatLevel = .none

                // 如果摄像头是因为LiDAR而停止的，重新启动摄像头
                if cameraStoppedByLiDAR, let camera = cameraController {
                    camera.start()
                    cameraStoppedByLiDAR = false
                    print("📷 摄像头已重新启动")
                }

                print("✅ LiDAR距离感知及所有相关功能已关闭并重置")
            }
        }
    }

    /// 当前检测到的距离（米）
    private(set) var currentDistance: Float = 0

    /// 当前威胁等级
    private(set) var threatLevel: DistanceThreatLevel = .none

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

    /// 是否启用语音距离播报
    public var voiceDistanceEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "lidarVoiceDistanceEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lidarVoiceDistanceEnabled")
        }
    }

    /// 是否启用摄像头控制（启用LiDAR时自动关闭摄像头）
    public var cameraControlEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "lidarCameraControlEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lidarCameraControlEnabled")
        }
    }

    /// 摄像头控制器引用（用于在启用LiDAR时停止摄像头）
    private weak var cameraController: CameraController?

    /// 摄像头是否因LiDAR而被停止
    private var cameraStoppedByLiDAR = false

    /// 语音播报计时器
    private var voiceTimer: Timer?

    /// 上次语音播报的距离
    private var lastVoiceDistance: Float = -1

    /// 上次触觉反馈日志时间
    private var lastHapticLogTime: CFTimeInterval = 0

    /// 初始化
    private override init() {
        super.init()

        // 设置默认值（如果尚未设置）
        if !UserDefaults.standard.bool(forKey: "lidarDistanceSettingsInitialized") {
            UserDefaults.standard.set(false, forKey: "lidarDistanceSensingEnabled") // 默认关闭LiDAR
            UserDefaults.standard.set(false, forKey: "lidarHapticFeedbackEnabled") // 默认关闭震动反馈
            UserDefaults.standard.set(false, forKey: "lidarVoiceDistanceEnabled") // 默认关闭语音播报
            UserDefaults.standard.set(false, forKey: "lidarCameraControlEnabled") // 默认关闭摄像头控制
            UserDefaults.standard.set(1.0, forKey: "lidarHighThreatThreshold")
            UserDefaults.standard.set(2.0, forKey: "lidarMediumThreatThreshold")
            UserDefaults.standard.set(5.0, forKey: "lidarLowThreatThreshold")
            UserDefaults.standard.set(true, forKey: "lidarDistanceSettingsInitialized")
            print("✅ LiDAR默认设置已初始化：所有功能默认关闭")
        }

        // 添加调试信息
        print("🔍 LiDAR设置状态检查：")
        print("  - 主开关: \(isEnabled)")
        print("  - 震动反馈: \(hapticFeedbackEnabled)")
        print("  - 语音播报: \(voiceDistanceEnabled)")
        print("  - 摄像头控制: \(cameraControlEnabled)")

        // 不自动启动LiDAR，让用户手动控制
        print("📱 应用启动完成，等待用户手动启用LiDAR功能")
    }

    /// 重置所有LiDAR设置到默认状态（用于调试）
    public func resetToDefaults() {
        print("🔄 重置LiDAR设置到默认状态")
        UserDefaults.standard.removeObject(forKey: "lidarDistanceSettingsInitialized")
        UserDefaults.standard.removeObject(forKey: "lidarDistanceSensingEnabled")
        UserDefaults.standard.removeObject(forKey: "lidarHapticFeedbackEnabled")
        UserDefaults.standard.removeObject(forKey: "lidarVoiceDistanceEnabled")
        UserDefaults.standard.removeObject(forKey: "lidarCameraControlEnabled")

        // 重新初始化默认值
        if !UserDefaults.standard.bool(forKey: "lidarDistanceSettingsInitialized") {
            UserDefaults.standard.set(false, forKey: "lidarDistanceSensingEnabled")
            UserDefaults.standard.set(false, forKey: "lidarHapticFeedbackEnabled")
            UserDefaults.standard.set(false, forKey: "lidarVoiceDistanceEnabled")
            UserDefaults.standard.set(false, forKey: "lidarCameraControlEnabled")
            UserDefaults.standard.set(1.0, forKey: "lidarHighThreatThreshold")
            UserDefaults.standard.set(2.0, forKey: "lidarMediumThreatThreshold")
            UserDefaults.standard.set(5.0, forKey: "lidarLowThreatThreshold")
            UserDefaults.standard.set(true, forKey: "lidarDistanceSettingsInitialized")
        }

        print("✅ LiDAR设置重置完成")
    }

    /// 设置摄像头控制器引用
    public func setCameraController(_ controller: CameraController) {
        self.cameraController = controller
    }

    /// 启动AR会话
    func startSession() {
        // 如果会话已经存在，先停止它
        if let existingSession = arSession {
            existingSession.pause()
            print("停止现有LiDAR会话")
        }

        // 检查设备是否支持LiDAR
        guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            print("设备不支持LiDAR")
            return
        }

        // 创建AR会话
        let session = ARSession()
        session.delegate = self

        // 创建AR配置 - 使用更轻量级的ARWorldTrackingConfiguration
        let configuration = ARWorldTrackingConfiguration()

        // 关键设置：不使用场景重建，减少资源占用
        if #available(iOS 13.4, *) {
            configuration.sceneReconstruction = []
        }

        // 只请求深度数据，不使用其他摄像头功能
        configuration.frameSemantics = [.sceneDepth]

        // 禁用所有不必要的功能，减少资源冲突
        configuration.isAutoFocusEnabled = false
        configuration.environmentTexturing = .none
        configuration.planeDetection = []
        configuration.initialWorldMap = nil

        // 设置低分辨率和低帧率，减少资源占用
        if #available(iOS 13.0, *) {
            configuration.videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats
                .filter { $0.imageResolution.width <= 1280 } // 使用较低分辨率
                .min(by: { $0.imageResolution.width < $1.imageResolution.width }) ?? ARWorldTrackingConfiguration.supportedVideoFormats.first!
        }

        do {
            // 使用特殊选项启动会话，尽量减少对其他摄像头使用的干扰
            let options: ARSession.RunOptions = [.removeExistingAnchors]

            // 启动会话
            session.run(configuration, options: options)

            // 保存会话和配置
            arSession = session
            arConfiguration = configuration

            print("LiDAR会话已启动 - 使用低资源模式")

            // 启动后立即进行一次测试，确认深度数据可用
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self, self.isEnabled else { return }

                if let frame = session.currentFrame, frame.sceneDepth != nil {
                    print("LiDAR深度数据正常获取")
                } else {
                    print("警告：无法获取LiDAR深度数据，可能需要重新启动会话")
                    // 如果无法获取深度数据，尝试重新启动
                    self.restartSession()
                }
            }
        } catch {
            print("启动LiDAR会话失败: \(error.localizedDescription)")
        }
    }

    /// 停止AR会话
    func stopSession() {
        if let session = arSession {
            session.pause()
            print("LiDAR会话已停止")
        }
        // 清除引用，释放资源
        arSession = nil
        arConfiguration = nil
    }

    /// 重新启动AR会话
    func restartSession() {
        print("尝试重新启动LiDAR会话...")
        stopSession()

        // 延迟一段时间后重新启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.isEnabled else { return }
            self.startSession()
        }
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // 获取深度数据
        guard let depthData = frame.sceneDepth?.depthMap else {
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

        // 计算前方障碍物的距离
        let distance = calculateFrontDistance(from: depthData)

        // 如果距离无效（为0），可能是深度数据问题
        if distance <= 0 && currentDistance > 0 {
            // 保持当前距离不变，避免突然变化
            return
        }

        // 更新当前距离
        currentDistance = distance

        // 更新威胁等级
        updateThreatLevel(for: distance)

        // 如果启用了振动反馈，根据威胁等级提供反馈
        if hapticFeedbackEnabled {
            print("🎮 触觉反馈已启用，距离: \(distance)米, 威胁等级: \(threatLevel)")
            provideHapticFeedback(for: threatLevel)
        } else {
            // 确保停止振动反馈
            print("🔇 触觉反馈已禁用，停止震动")
            HapticFeedbackManager.shared.stopHapticFeedback()
        }

        // 如果启用了语音距离播报，提供语音反馈
        if voiceDistanceEnabled {
            provideVoiceDistanceAnnouncement(for: distance)
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR会话失败: \(error.localizedDescription)")

        // 如果是资源冲突错误，尝试重新启动会话
        if (error as NSError).code == -12784 {
            print("检测到资源冲突，尝试重新启动LiDAR会话")
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
        if isEnabled {
            stopSession()
            startSession()
        }
    }

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
        guard currentDistance > 0.1 && currentDistance <= lowThreatThreshold else {
            print("🛑 距离超出范围(\(currentDistance)米)，停止振动反馈")
            return
        }

        // 使用简化的基于距离的触觉反馈
        HapticFeedbackManager.shared.playHapticFeedback(forDistance: currentDistance)

        // 打印调试信息（减少频率以避免日志过多）
        let now = CACurrentMediaTime()
        if now - lastHapticLogTime > 1.0 { // 每秒最多打印一次
            let levelDesc = HapticFeedbackManager.shared.getHapticLevelDescription(for: currentDistance)
            print("🎮 振动反馈 - 距离: \(String(format: "%.2f", currentDistance))米, \(levelDesc)")
            lastHapticLogTime = now
        }
    }

    /// 提供语音距离播报
    private func provideVoiceDistanceAnnouncement(for distance: Float) {
        // 如果距离无效或超出播报范围，停止语音播报
        if distance <= 0 || distance > lowThreatThreshold {
            stopVoiceAnnouncement()
            return
        }

        // 检查距离变化是否足够大，避免频繁播报
        let distanceChange = abs(distance - lastVoiceDistance)
        let shouldAnnounce: Bool

        if lastVoiceDistance < 0 {
            // 首次播报
            shouldAnnounce = true
        } else if distance <= 1.0 {
            // 1米以内，变化0.1米就播报
            shouldAnnounce = distanceChange >= 0.1
        } else if distance <= 3.0 {
            // 1-3米，变化0.3米就播报
            shouldAnnounce = distanceChange >= 0.3
        } else {
            // 3米以上，变化0.5米就播报
            shouldAnnounce = distanceChange >= 0.5
        }

        if shouldAnnounce {
            lastVoiceDistance = distance

            // 格式化距离文本
            let distanceText: String
            if distance < 1.0 {
                // 小于1米时用厘米表示
                let centimeters = Int(distance * 100)
                distanceText = "前方\(centimeters)厘米"
            } else {
                // 大于等于1米时用米表示
                distanceText = String(format: "前方%.1f米", distance)
            }

            // 使用语音合成器播报距离
            SpeechSynthesizer.shared.speak(distanceText, rate: 0.6, forceSpeak: true)

            print("语音播报: \(distanceText)")
        }
    }

    /// 停止语音播报
    private func stopVoiceAnnouncement() {
        voiceTimer?.invalidate()
        voiceTimer = nil
        lastVoiceDistance = -1
    }
}
