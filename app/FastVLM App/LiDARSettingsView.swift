//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import SwiftUI

/// LiDAR距离感知设置视图
struct LiDARSettingsView: View {
    @Environment(\.dismiss) var dismiss

    // 直接使用共享实例，而不是创建状态副本
    private var lidarSensor: LiDARDistanceSensor {
        LiDARDistanceSensor.shared
    }

    var body: some View {
        NavigationStack {
            Form {
                // 距离阈值设置
                Section("距离阈值设置") {
                    // 高威胁阈值
                    VStack(alignment: .leading) {
                        Text("高威胁阈值：\(String(format: "%.1f", lidarSensor.highThreatThreshold))米")
                            .font(.subheadline)

                        Slider(value: Binding(
                            get: { lidarSensor.highThreatThreshold },
                            set: { lidarSensor.highThreatThreshold = $0 }
                        ), in: 0.5...2.0, step: 0.1)
                        .accentColor(.red)
                    }
                    .padding(.vertical, 4)

                    // 中等威胁阈值
                    VStack(alignment: .leading) {
                        Text("中等威胁阈值：\(String(format: "%.1f", lidarSensor.mediumThreatThreshold))米")
                            .font(.subheadline)

                        Slider(value: Binding(
                            get: { lidarSensor.mediumThreatThreshold },
                            set: { lidarSensor.mediumThreatThreshold = $0 }
                        ), in: lidarSensor.highThreatThreshold + 0.5...4.0, step: 0.1)
                        .accentColor(.orange)
                    }
                    .padding(.vertical, 4)

                    // 低威胁阈值
                    VStack(alignment: .leading) {
                        Text("低威胁阈值：\(String(format: "%.1f", lidarSensor.lowThreatThreshold))米")
                            .font(.subheadline)

                        Slider(value: Binding(
                            get: { lidarSensor.lowThreatThreshold },
                            set: { lidarSensor.lowThreatThreshold = $0 }
                        ), in: lidarSensor.mediumThreatThreshold + 0.5...10.0, step: 0.5)
                        .accentColor(.yellow)
                    }
                    .padding(.vertical, 4)
                }

                // 反馈设置（仅在LiDAR启用时可用）
                Section("反馈设置") {
                    Toggle(isOn: Binding(
                        get: { lidarSensor.hapticFeedbackEnabled },
                        set: { newValue in
                            // 只有在主开关开启时才允许修改
                            guard lidarSensor.isEnabled else {
                                print("⚠️ [设置] LiDAR未启用，无法修改振动反馈设置")
                                return
                            }
                            print("🔄 [设置] 振动反馈开关切换: \(lidarSensor.hapticFeedbackEnabled) -> \(newValue)")
                            lidarSensor.hapticFeedbackEnabled = newValue
                        }
                    )) {
                        HStack {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundColor(.accentColor)
                            Text("启用振动反馈")
                                .font(.subheadline)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .disabled(!lidarSensor.isEnabled) // LiDAR未启用时禁用

                    Toggle(isOn: Binding(
                        get: { lidarSensor.voiceDistanceEnabled },
                        set: { newValue in
                            // 只有在主开关开启时才允许修改
                            guard lidarSensor.isEnabled else {
                                print("⚠️ [设置] LiDAR未启用，无法修改语音播报设置")
                                return
                            }
                            print("🔄 [设置] 语音播报开关切换: \(lidarSensor.voiceDistanceEnabled) -> \(newValue)")
                            lidarSensor.voiceDistanceEnabled = newValue
                        }
                    )) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.accentColor)
                            Text("启用语音距离播报")
                                .font(.subheadline)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .disabled(!lidarSensor.isEnabled) // LiDAR未启用时禁用

                    Toggle(isOn: Binding(
                        get: { lidarSensor.cameraControlEnabled },
                        set: { newValue in
                            // 只有在主开关开启时才允许修改
                            guard lidarSensor.isEnabled else {
                                print("⚠️ [设置] LiDAR未启用，无法修改摄像头控制设置")
                                return
                            }
                            print("🔄 [设置] 摄像头控制开关切换: \(lidarSensor.cameraControlEnabled) -> \(newValue)")
                            lidarSensor.cameraControlEnabled = newValue
                        }
                    )) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("启用摄像头控制")
                                    .font(.subheadline)
                                Text("开启时LiDAR会自动关闭摄像头，关闭时两者并行运行")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .disabled(!lidarSensor.isEnabled) // LiDAR未启用时禁用

                    if lidarSensor.hapticFeedbackEnabled {
                        // 触觉反馈诊断按钮
                        Button {
                            HapticFeedbackManager.shared.testHapticFeedback()
                        } label: {
                            HStack {
                                Image(systemName: "stethoscope")
                                    .foregroundColor(.blue)
                                Text("诊断触觉反馈")
                                    .font(.subheadline)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderless)

                        // 测试振动按钮 - 使用新的简化API
                        VStack(spacing: 8) {
                            Button {
                                // 测试远距离振动（轻微）
                                HapticFeedbackManager.shared.playHapticFeedback(forDistance: 4.0)
                            } label: {
                                Text("测试远距离振动 (4米)")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.yellow)

                            Button {
                                // 测试中距离振动（中等）
                                HapticFeedbackManager.shared.playHapticFeedback(forDistance: 2.0)
                            } label: {
                                Text("测试中距离振动 (2米)")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)

                            Button {
                                // 测试近距离振动（强烈）
                                HapticFeedbackManager.shared.playHapticFeedback(forDistance: 0.5)
                            } label: {
                                Text("测试近距离振动 (0.5米)")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    }
                }

                // 当前状态显示
                Section("当前状态") {
                    if lidarSensor.isEnabled {
                        HStack {
                            Text("当前距离：")
                                .font(.subheadline)
                            Spacer()
                            Text("\(String(format: "%.2f", lidarSensor.currentDistance))米")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }

                        HStack {
                            Text("威胁等级：")
                                .font(.subheadline)
                            Spacer()
                            Text(lidarSensor.threatLevel.description)
                                .font(.subheadline)
                                .foregroundColor(lidarSensor.threatLevel.color)
                        }
                    } else {
                        Text("LiDAR距离感知未启用")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // 调试和重置
                Section("调试工具") {
                    Button {
                        LiDARDiagnosticTests.shared.runFullDiagnostic()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.badge.questionmark")
                                .foregroundColor(.blue)
                            Text("运行完整诊断")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        lidarSensor.resetToDefaults()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.orange)
                            Text("重置所有设置")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        LiDARDiagnosticTests.shared.resetAndRetest()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle")
                                .foregroundColor(.red)
                            Text("重置并重新测试")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        LiDARDiagnosticTests.shared.testUIStateSynchronization()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.purple)
                            Text("测试UI状态同步")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        LiDARDiagnosticTests.shared.forceStopAllHapticFeedback()
                    } label: {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                                .foregroundColor(.red)
                            Text("强制停止触觉反馈")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        LiDARDiagnosticTests.shared.testSimplifiedHapticSystem()
                    } label: {
                        HStack {
                            Image(systemName: "waveform.path.ecg")
                                .foregroundColor(.mint)
                            Text("测试简化触觉系统")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        RefactorValidation.validateRefactor()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.seal")
                                .foregroundColor(.green)
                            Text("验证重构结果")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        FinalCompilationTest.runCompleteTest()
                    } label: {
                        HStack {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.orange)
                            Text("运行最终测试")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        LiDARDiagnosticTests.shared.testMasterSlaveToggleLogic()
                    } label: {
                        HStack {
                            Image(systemName: "switch.2")
                                .foregroundColor(.blue)
                            Text("测试主从开关逻辑")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        LiDARDiagnosticTests.shared.validateDefaultState()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.cyan)
                            Text("验证默认状态")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        LiDARDiagnosticTests.shared.testMasterSwitchFunctionality()
                    } label: {
                        HStack {
                            Image(systemName: "power")
                                .foregroundColor(.red)
                            Text("测试主开关功能")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        LiDARDiagnosticTests.shared.quickFunctionVerification()
                    } label: {
                        HStack {
                            Image(systemName: "bolt.circle")
                                .foregroundColor(.yellow)
                            Text("快速功能验证")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                }

                // 说明信息
                Section("说明") {
                    Text("LiDAR距离感知功能使用iPhone的激光雷达传感器检测前方障碍物的距离，并根据距离提供不同强度的振动反馈。")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Text("此功能仅支持iPhone 12 Pro、iPhone 12 Pro Max及更高规格的机型。")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Text("如果遇到问题，可以尝试重置所有设置或使用诊断工具检查触觉反馈功能。")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("LiDAR距离感知设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    LiDARSettingsView()
}
