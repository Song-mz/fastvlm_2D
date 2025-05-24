//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import SwiftUI
import AVFoundation
import ARKit
import CoreHaptics

@main
struct FastVLMApp: App {
    init() {
        // 请求语音合成权限
        requestSpeechPermission()

        // 请求ARKit权限
        requestARPermission()

        // 初始化触觉引擎
        initializeHapticEngine()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    /// 请求语音合成权限
    private func requestSpeechPermission() {
        // AVSpeechSynthesizer不需要明确的权限请求，但我们可以预先初始化它
        // 这样可以确保在用户首次使用时不会有延迟
        _ = SpeechSynthesizer.shared
    }

    /// 请求ARKit权限
    private func requestARPermission() {
        // ARKit不需要明确的权限请求，但相机权限是必需的
        // 我们可以预先初始化LiDAR传感器，确保在用户首次使用时不会有延迟
        _ = LiDARDistanceSensor.shared
    }

    /// 初始化触觉引擎
    private func initializeHapticEngine() {
        // 预先初始化触觉引擎，确保在用户首次使用时不会有延迟
        _ = HapticFeedbackManager.shared
    }
}
