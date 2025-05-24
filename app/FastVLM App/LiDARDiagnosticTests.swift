//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
import CoreHaptics
import AVFoundation
import UIKit

// String重复操作符扩展
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

/// LiDAR和触觉反馈诊断测试工具
class LiDARDiagnosticTests {

    static let shared = LiDARDiagnosticTests()

    private init() {}

    /// 运行完整的诊断测试
    func runFullDiagnostic() {
        print("🧪 开始LiDAR和触觉反馈完整诊断")
        print("=" * 50)

        // 1. 检查UserDefaults设置
        checkUserDefaultsSettings()

        // 2. 检查设备硬件支持
        checkHardwareSupport()

        // 3. 检查触觉引擎状态
        checkHapticEngineStatus()

        // 4. 测试触觉反馈
        testHapticFeedback()

        // 5. 检查LiDAR传感器状态
        checkLiDARSensorStatus()

        print("=" * 50)
        print("🧪 诊断测试完成")
    }

    /// 检查UserDefaults设置
    private func checkUserDefaultsSettings() {
        print("\n📋 检查UserDefaults设置:")

        let settings = [
            ("lidarDistanceSettingsInitialized", UserDefaults.standard.bool(forKey: "lidarDistanceSettingsInitialized")),
            ("lidarDistanceSensingEnabled", UserDefaults.standard.bool(forKey: "lidarDistanceSensingEnabled")),
            ("lidarHapticFeedbackEnabled", UserDefaults.standard.bool(forKey: "lidarHapticFeedbackEnabled")),
            ("lidarVoiceDistanceEnabled", UserDefaults.standard.bool(forKey: "lidarVoiceDistanceEnabled")),
            ("lidarCameraControlEnabled", UserDefaults.standard.bool(forKey: "lidarCameraControlEnabled"))
        ]

        for (key, value) in settings {
            let status = value ? "✅" : "❌"
            print("  \(status) \(key): \(value)")
        }

        // 检查阈值设置
        let thresholds = [
            ("lidarHighThreatThreshold", UserDefaults.standard.float(forKey: "lidarHighThreatThreshold")),
            ("lidarMediumThreatThreshold", UserDefaults.standard.float(forKey: "lidarMediumThreatThreshold")),
            ("lidarLowThreatThreshold", UserDefaults.standard.float(forKey: "lidarLowThreatThreshold"))
        ]

        for (key, value) in thresholds {
            print("  📏 \(key): \(value)米")
        }
    }

    /// 检查设备硬件支持
    private func checkHardwareSupport() {
        print("\n🔧 检查设备硬件支持:")

        // 检查触觉反馈支持
        let hapticCapabilities = CHHapticEngine.capabilitiesForHardware()
        print("  触觉反馈支持: \(hapticCapabilities.supportsHaptics ? "✅" : "❌")")
        print("  音频支持: \(hapticCapabilities.supportsAudio ? "✅" : "❌")")

        // 检查设备型号（简单检查）
        let deviceModel = UIDevice.current.model
        print("  设备型号: \(deviceModel)")

        // 检查iOS版本
        let systemVersion = UIDevice.current.systemVersion
        print("  iOS版本: \(systemVersion)")
    }

    /// 检查触觉引擎状态
    private func checkHapticEngineStatus() {
        print("\n⚡ 检查触觉引擎状态:")

        let hapticManager = HapticFeedbackManager.shared

        // 运行触觉反馈测试
        hapticManager.testHapticFeedback()
    }

    /// 测试触觉反馈
    private func testHapticFeedback() {
        print("\n🎮 测试触觉反馈:")

        let hapticManager = HapticFeedbackManager.shared

        // 测试简单触觉反馈
        print("  测试简单触觉反馈...")
        hapticManager.playSimpleHapticFeedback()

        // 延迟测试触觉反馈
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("  测试触觉反馈（距离1米）...")
            hapticManager.playHapticFeedback(forDistance: 1.0)

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("  停止触觉反馈...")
                hapticManager.stopHapticFeedback()
            }
        }
    }

    /// 检查LiDAR传感器状态
    private func checkLiDARSensorStatus() {
        print("\n📡 检查LiDAR传感器状态:")

        let lidarSensor = LiDARDistanceSensor.shared

        print("  主开关状态: \(lidarSensor.isEnabled ? "✅ 开启" : "❌ 关闭")")
        print("  震动反馈: \(lidarSensor.hapticFeedbackEnabled ? "✅ 开启" : "❌ 关闭")")
        print("  语音播报: \(lidarSensor.voiceDistanceEnabled ? "✅ 开启" : "❌ 关闭")")
        print("  摄像头控制: \(lidarSensor.cameraControlEnabled ? "✅ 开启" : "❌ 关闭")")
        print("  当前距离: \(lidarSensor.currentDistance)米")
        print("  威胁等级: \(lidarSensor.threatLevel.description)")
    }

    /// 重置所有设置并重新测试
    func resetAndRetest() {
        print("🔄 重置所有设置并重新测试")

        // 重置LiDAR设置
        LiDARDistanceSensor.shared.resetToDefaults()

        // 延迟后重新运行诊断
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.runFullDiagnostic()
        }
    }

    /// 测试UI状态同步
    func testUIStateSynchronization() {
        print("\n🔄 测试UI状态同步")
        print("=" * 50)

        let sensor = LiDARDistanceSensor.shared

        // 记录当前状态
        let initialStates = [
            ("LiDAR主开关", sensor.isEnabled),
            ("振动反馈", sensor.hapticFeedbackEnabled),
            ("语音播报", sensor.voiceDistanceEnabled),
            ("摄像头控制", sensor.cameraControlEnabled)
        ]

        print("初始状态:")
        for (name, state) in initialStates {
            print("  \(name): \(state ? "✅ 开启" : "❌ 关闭")")
        }

        // 测试开关切换
        print("\n测试开关切换:")

        // 切换LiDAR主开关
        let oldLidarState = sensor.isEnabled
        sensor.isEnabled = !oldLidarState
        let newLidarState = sensor.isEnabled
        print("  LiDAR主开关: \(oldLidarState) -> \(newLidarState) \(newLidarState != oldLidarState ? "✅" : "❌")")

        // 切换振动反馈
        let oldHapticState = sensor.hapticFeedbackEnabled
        sensor.hapticFeedbackEnabled = !oldHapticState
        let newHapticState = sensor.hapticFeedbackEnabled
        print("  振动反馈: \(oldHapticState) -> \(newHapticState) \(newHapticState != oldHapticState ? "✅" : "❌")")

        // 恢复原始状态
        sensor.isEnabled = oldLidarState
        sensor.hapticFeedbackEnabled = oldHapticState

        print("\n状态已恢复到初始值")
        print("=" * 50)
    }

    /// 强制停止所有触觉反馈
    func forceStopAllHapticFeedback() {
        print("\n🛑 强制停止所有触觉反馈")

        // 停止触觉反馈
        HapticFeedbackManager.shared.stopHapticFeedback()

        // 确保LiDAR传感器状态正确
        let sensor = LiDARDistanceSensor.shared
        if !sensor.isEnabled || !sensor.hapticFeedbackEnabled {
            print("✅ LiDAR或触觉反馈已关闭，触觉反馈已停止")
        }

        print("🛑 所有触觉反馈已强制停止")
    }

    /// 测试新的简化触觉反馈系统
    func testSimplifiedHapticSystem() {
        print("\n🎮 测试简化触觉反馈系统")
        print("=" * 50)

        let hapticManager = HapticFeedbackManager.shared

        // 测试不同距离的触觉反馈
        let testDistances: [Float] = [0.2, 0.5, 1.0, 2.0, 3.0, 5.0]

        print("测试距离范围: 0.2米 - 5.0米")
        print("预期效果: 距离越近，振动越强")
        print("")

        for (index, distance) in testDistances.enumerated() {
            let levelDesc = hapticManager.getHapticLevelDescription(for: distance)
            print("距离 \(distance)米: \(levelDesc)")

            // 延迟播放，避免重叠
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 1.0) {
                hapticManager.playHapticFeedback(forDistance: distance)
            }
        }

        print("\n🎮 简化触觉反馈系统测试完成")
        print("=" * 50)
    }

    /// 测试主从开关逻辑
    func testMasterSlaveToggleLogic() {
        print("\n🔄 测试主从开关逻辑")
        print("=" * 50)

        let sensor = LiDARDistanceSensor.shared

        // 记录初始状态
        print("初始状态:")
        printAllSwitchStates(sensor)

        // 测试1：开启主开关
        print("\n🔥 测试1：开启主开关")
        sensor.isEnabled = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("开启主开关后的状态:")
            self.printAllSwitchStates(sensor)

            // 测试2：关闭主开关
            print("\n🔥 测试2：关闭主开关")
            sensor.isEnabled = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("关闭主开关后的状态:")
                self.printAllSwitchStates(sensor)

                print("\n✅ 主从开关逻辑测试完成")
                print("=" * 50)
            }
        }
    }

    /// 打印所有开关状态
    private func printAllSwitchStates(_ sensor: LiDARDistanceSensor) {
        print("  - 主开关(LiDAR): \(sensor.isEnabled ? "✅ 开启" : "❌ 关闭")")
        print("  - 振动反馈: \(sensor.hapticFeedbackEnabled ? "✅ 开启" : "❌ 关闭")")
        print("  - 语音播报: \(sensor.voiceDistanceEnabled ? "✅ 开启" : "❌ 关闭")")
        print("  - 摄像头控制: \(sensor.cameraControlEnabled ? "✅ 开启" : "❌ 关闭")")
        print("  - 当前距离: \(sensor.currentDistance)米")
        print("  - 威胁等级: \(sensor.threatLevel.description)")
    }

    /// 验证默认状态
    func validateDefaultState() {
        print("\n🔍 验证默认状态")
        print("=" * 30)

        let sensor = LiDARDistanceSensor.shared

        let expectedDefaults = [
            ("主开关", sensor.isEnabled, false),
            ("振动反馈", sensor.hapticFeedbackEnabled, false),
            ("语音播报", sensor.voiceDistanceEnabled, false),
            ("摄像头控制", sensor.cameraControlEnabled, false)
        ]

        var allCorrect = true

        for (name, actual, expected) in expectedDefaults {
            let isCorrect = actual == expected
            let status = isCorrect ? "✅" : "❌"
            print("  \(status) \(name): \(actual) (期望: \(expected))")

            if !isCorrect {
                allCorrect = false
            }
        }

        if allCorrect {
            print("\n🎉 所有默认状态正确！")
        } else {
            print("\n⚠️ 发现状态不正确，需要重置")
            sensor.resetToDefaults()
        }

        print("=" * 30)
    }

    /// 测试主开关是否真正启用所有功能
    func testMasterSwitchFunctionality() {
        print("\n🔥 测试主开关功能启用")
        print("=" * 50)

        let sensor = LiDARDistanceSensor.shared

        // 首先确保所有功能关闭
        print("步骤1：重置所有功能到关闭状态")
        sensor.isEnabled = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("重置后状态:")
            self.printAllSwitchStates(sensor)
            self.printUserDefaultsStates()

            // 开启主开关
            print("\n步骤2：开启主开关")
            sensor.isEnabled = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("开启主开关后状态:")
                self.printAllSwitchStates(sensor)
                self.printUserDefaultsStates()

                // 验证功能是否真正启用
                print("\n步骤3：验证功能是否真正启用")
                self.verifyFunctionsEnabled(sensor)

                print("\n✅ 主开关功能测试完成")
                print("=" * 50)
            }
        }
    }

    /// 打印UserDefaults状态
    private func printUserDefaultsStates() {
        print("UserDefaults状态:")
        print("  - lidarDistanceSensingEnabled: \(UserDefaults.standard.bool(forKey: "lidarDistanceSensingEnabled"))")
        print("  - lidarHapticFeedbackEnabled: \(UserDefaults.standard.bool(forKey: "lidarHapticFeedbackEnabled"))")
        print("  - lidarVoiceDistanceEnabled: \(UserDefaults.standard.bool(forKey: "lidarVoiceDistanceEnabled"))")
        print("  - lidarCameraControlEnabled: \(UserDefaults.standard.bool(forKey: "lidarCameraControlEnabled"))")
    }

    /// 验证功能是否真正启用
    private func verifyFunctionsEnabled(_ sensor: LiDARDistanceSensor) {
        let checks = [
            ("LiDAR传感器", sensor.isEnabled),
            ("触觉反馈", sensor.hapticFeedbackEnabled),
            ("语音播报", sensor.voiceDistanceEnabled),
            ("摄像头控制", sensor.cameraControlEnabled)
        ]

        var allEnabled = true

        for (name, enabled) in checks {
            let status = enabled ? "✅ 已启用" : "❌ 未启用"
            print("  \(name): \(status)")

            if !enabled {
                allEnabled = false
            }
        }

        if allEnabled {
            print("\n🎉 所有功能已正确启用！")

            // 测试触觉反馈是否工作
            print("测试触觉反馈...")
            HapticFeedbackManager.shared.playHapticFeedback(forDistance: 1.0)

        } else {
            print("\n⚠️ 发现功能未正确启用！")
        }
    }

    /// 快速功能验证
    func quickFunctionVerification() {
        print("\n⚡ 快速功能验证")
        print("=" * 30)

        let sensor = LiDARDistanceSensor.shared

        print("当前状态:")
        print("  LiDAR: \(sensor.isEnabled ? "开启" : "关闭")")
        print("  触觉: \(sensor.hapticFeedbackEnabled ? "开启" : "关闭")")
        print("  语音: \(sensor.voiceDistanceEnabled ? "开启" : "关闭")")
        print("  摄像头: \(sensor.cameraControlEnabled ? "开启" : "关闭")")

        if sensor.isEnabled && sensor.hapticFeedbackEnabled {
            print("\n🎮 测试触觉反馈...")
            HapticFeedbackManager.shared.playHapticFeedback(forDistance: 0.5)
            print("✅ 触觉反馈测试完成")
        } else {
            print("\n⚠️ 触觉反馈未启用，无法测试")
        }

        print("=" * 30)
    }
}
