//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import SwiftUI

/// LiDAR距离显示视图 - 重构版本
struct LiDARDistanceView: View {
    @State private var isShowingSettings = false

    // 使用@AppStorage直接绑定UserDefaults，确保UI状态同步
    @AppStorage("lidarDistanceSensingEnabled") private var isLiDAREnabled = false
    @AppStorage("lidarHapticFeedbackEnabled") private var isHapticEnabled = false
    @AppStorage("lidarVoiceDistanceEnabled") private var isVoiceEnabled = false
    @AppStorage("lidarCameraControlEnabled") private var isCameraControlEnabled = false

    // 直接使用共享实例获取距离数据
    private var lidarSensor: LiDARDistanceSensor {
        LiDARDistanceSensor.shared
    }

    var body: some View {
        VStack(spacing: 16) {
            // LiDAR距离感知主开关
            Toggle(isOn: Binding(
                get: { isLiDAREnabled },
                set: { newValue in
                    print("🔄 LiDAR主开关切换: \(isLiDAREnabled) -> \(newValue)")

                    // 同步到LiDAR传感器（这会自动设置UserDefaults，UI会自动更新）
                    lidarSensor.isEnabled = newValue

                    print("✅ 主开关状态已更新，子功能将自动跟随")
                }
            )) {
                HStack {
                    Image(systemName: "sensor")
                        .foregroundColor(.accentColor)
                    Text("LiDAR距离感知")
                        .font(.subheadline)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))

            // 如果启用了LiDAR距离感知，显示当前状态和控制选项
            if isLiDAREnabled {
                VStack(spacing: 12) {
                    // 距离和威胁等级显示
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("当前距离")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if lidarSensor.currentDistance > 0 {
                                Text("\(String(format: "%.2f", lidarSensor.currentDistance))米")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(lidarSensor.threatLevel.color)
                            } else {
                                Text("检测中...")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("威胁等级")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(lidarSensor.threatLevel.description)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(lidarSensor.threatLevel.color)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)

                    // 功能开关
                    VStack(spacing: 8) {
                        // 振动反馈开关（仅在主开关开启时可用）
                        Toggle(isOn: Binding(
                            get: { isHapticEnabled },
                            set: { newValue in
                                // 只有在主开关开启时才允许修改
                                guard isLiDAREnabled else {
                                    print("⚠️ 主开关未开启，无法修改振动反馈设置")
                                    return
                                }
                                print("🔄 振动反馈开关切换: \(isHapticEnabled) -> \(newValue)")
                                isHapticEnabled = newValue
                                lidarSensor.hapticFeedbackEnabled = newValue
                            }
                        )) {
                            HStack {
                                Image(systemName: "iphone.radiowaves.left.and.right")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("振动反馈")
                                        .font(.subheadline)
                                    if isHapticEnabled && lidarSensor.currentDistance > 0.1 {
                                        Text(HapticFeedbackManager.shared.getHapticLevelDescription(for: lidarSensor.currentDistance))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        .disabled(!isLiDAREnabled) // 主开关关闭时禁用

                        // 语音距离播报开关（仅在主开关开启时可用）
                        Toggle(isOn: Binding(
                            get: { isVoiceEnabled },
                            set: { newValue in
                                // 只有在主开关开启时才允许修改
                                guard isLiDAREnabled else {
                                    print("⚠️ 主开关未开启，无法修改语音播报设置")
                                    return
                                }
                                print("🔄 语音播报开关切换: \(isVoiceEnabled) -> \(newValue)")
                                isVoiceEnabled = newValue
                                lidarSensor.voiceDistanceEnabled = newValue
                            }
                        )) {
                            HStack {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.accentColor)
                                Text("语音距离播报")
                                    .font(.subheadline)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        .disabled(!isLiDAREnabled) // 主开关关闭时禁用

                        // 摄像头控制开关（仅在主开关开启时可用）
                        Toggle(isOn: Binding(
                            get: { isCameraControlEnabled },
                            set: { newValue in
                                // 只有在主开关开启时才允许修改
                                guard isLiDAREnabled else {
                                    print("⚠️ 主开关未开启，无法修改摄像头控制设置")
                                    return
                                }
                                print("🔄 摄像头控制开关切换: \(isCameraControlEnabled) -> \(newValue)")
                                isCameraControlEnabled = newValue
                                lidarSensor.cameraControlEnabled = newValue
                            }
                        )) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("摄像头控制")
                                        .font(.subheadline)
                                    Text("启用时LiDAR会自动关闭摄像头")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                        .disabled(!isLiDAREnabled) // 主开关关闭时禁用
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }
                .transition(.opacity.combined(with: .scale))
            }

            // 设置按钮
            Button {
                isShowingSettings = true
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("LiDAR设置")
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 4)
        .animation(.easeInOut(duration: 0.2), value: isLiDAREnabled)
        .onAppear {
            // 🔥 应用启动时检查状态并确保同步
            print("📱 LiDAR视图出现，当前状态：")
            print("  - LiDAR: \(isLiDAREnabled), 触觉: \(isHapticEnabled), 语音: \(isVoiceEnabled), 摄像头: \(isCameraControlEnabled)")

            // 确保LiDAR传感器状态与UserDefaults同步
            lidarSensor.isEnabled = isLiDAREnabled
            lidarSensor.hapticFeedbackEnabled = isHapticEnabled
            lidarSensor.voiceDistanceEnabled = isVoiceEnabled
            lidarSensor.cameraControlEnabled = isCameraControlEnabled

            // 如果功能关闭，确保停止所有反馈
            if !isLiDAREnabled {
                HapticFeedbackManager.shared.stopHapticFeedback()
                print("🛑 LiDAR关闭，确保所有反馈已停止")
            }

            print("✅ 状态同步完成")
        }
        .sheet(isPresented: $isShowingSettings) {
            LiDARSettingsView()
        }
    }
}

#Preview {
    LiDARDistanceView()
        .padding()
}
