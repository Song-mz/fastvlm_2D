# 功能特性详细说明

## 🎯 LiDAR 距离感知系统

### 核心功能
LiDAR 距离感知系统是本项目的核心增强功能，利用 iPhone/iPad 的 LiDAR 传感器实现精确的距离检测和多模态反馈。

### 技术实现
```swift
// 核心检测逻辑
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    guard let depthData = frame.sceneDepth else { return }
    
    // 获取中心点深度
    let centerPoint = CGPoint(x: 0.5, y: 0.5)
    let distance = getDepthAtPoint(centerPoint, depthData: depthData)
    
    // 更新距离和威胁等级
    updateDistance(distance)
}
```

### 功能特性

#### 1. 实时距离检测
- **检测范围**: 0.1 - 5.0 米
- **精度**: 厘米级精度
- **更新频率**: 60 FPS
- **检测区域**: 屏幕中心点

#### 2. 三级威胁预警
| 威胁等级 | 默认距离 | 颜色标识 | 行为 |
|----------|----------|----------|------|
| 🔴 高危 | ≤ 1.0m | 红色 | 强烈振动 + 紧急语音 |
| 🟡 中危 | ≤ 2.0m | 黄色 | 中等振动 + 提醒语音 |
| 🟢 低危 | ≤ 5.0m | 绿色 | 轻微振动 + 距离播报 |
| ⚪ 安全 | > 5.0m | 白色 | 无反馈 |

#### 3. 20级触觉反馈
```swift
// 强度计算公式
let intensity = max(0.1, min(1.0, (5.1 - distance) / 5.0))
let sharpness = max(0.1, min(1.0, (5.1 - distance) / 5.0))

// 等级描述
Level 1 (4.8-5.0m): "极轻微感知"
Level 10 (2.3-2.5m): "明显振动"  
Level 20 (0.1-0.3m): "强烈警告"
```

#### 4. 智能语音播报
- **播报内容**: 当前距离 + 威胁等级
- **语音去重**: 避免重复播报相同内容
- **多语言支持**: 中文、英文等
- **可配置参数**: 语速、音调、音量

#### 5. 级联控制逻辑
```swift
// 启用主开关时
if lidarEnabled {
    hapticFeedbackEnabled = true      // 自动启用触觉反馈
    voiceDistanceEnabled = true       // 自动启用语音播报
    cameraControlEnabled = true       // 自动启用摄像头控制
}

// 禁用主开关时
if !lidarEnabled {
    // 停止所有反馈并重置状态
    stopAllFeedback()
    resetAllSettings()
}
```

### 使用场景
1. **视障辅助**: 为视障人士提供空间感知能力
2. **安全导航**: 在狭小或危险空间中的安全提醒
3. **机器人开发**: 作为避障系统的参考实现
4. **AR应用**: 增强现实应用的空间感知基础

---

## 🧠 图像相似度检测系统

### 功能概述
基于 Apple Vision 框架的高精度图像特征提取和相似度比较系统，智能减少重复处理。

### 技术原理
```swift
// 特征提取
let request = VNGenerateImageFeaturePrintRequest()
request.usesCPUOnly = false  // 使用 GPU 加速

// 相似度计算
var distance: Float = 0
try lastFeaturePrint.computeDistance(&distance, to: currentFeaturePrint)
let similarity = 1.0 - Double(distance)
```

### 核心特性

#### 1. 智能特征提取
- **算法**: VNFeaturePrintObservation
- **加速**: GPU 硬件加速
- **精度**: 高精度场景特征识别
- **性能**: 优化的特征向量计算

#### 2. 三种检测模式
```swift
enum SimilarityDetectionMode {
    case imageOnly   // 仅基于图像特征
    case textOnly    // 仅基于文本内容
    case combined    // 图像 + 文本组合
}
```

#### 3. 可配置参数
- **相似度阈值**: 0.0 - 1.0 (默认 0.7)
- **最小间隔**: 时间间隔控制 (默认 0.5s)
- **检测模式**: 灵活的检测策略选择

#### 4. 性能优化
- **智能跳帧**: 相似度高时跳过处理
- **资源节约**: 减少 AI 推理次数
- **电池优化**: 延长设备续航时间

### 决策逻辑
```swift
let shouldProcess = (similarity < threshold) || 
                   (timeSinceLastFeature >= minInterval) ||
                   isFirstFrame
```

---

## 🔊 智能语音合成系统

### 系统架构
增强的 AVSpeechSynthesizer 封装，具备智能去重和相似度检测功能。

### 核心算法

#### 1. 文本相似度计算
```swift
// 基于编辑距离的相似度算法
func calculateSimilarity(between text1: String, and text2: String) -> Double {
    let distance = levenshteinDistance(text1, text2)
    let maxLength = max(text1.count, text2.count)
    return maxLength > 0 ? 1.0 - Double(distance) / Double(maxLength) : 1.0
}
```

#### 2. 智能播报决策
```swift
func shouldSpeakNewDescription(
    newDescription: String,
    similarity: Double,
    timeSinceLastSpeech: TimeInterval
) -> Bool {
    // 首次播报
    if lastDescription.isEmpty { return true }
    
    // 强制播报模式
    if forceSpeak { return true }
    
    // 相似度检查
    if similarity < similarityThreshold { return true }
    
    // 时间间隔检查
    if timeSinceLastSpeech >= minSpeechInterval { return true }
    
    return false
}
```

### 功能特性

#### 1. 多语言支持
- **中文**: zh-CN (默认)
- **英文**: en-US
- **其他**: 支持系统所有语言

#### 2. 语音参数控制
```swift
utterance.rate = 0.5              // 语速 (0.0 - 1.0)
utterance.pitchMultiplier = 1.0   // 音调 (0.5 - 2.0)
utterance.volume = 1.0            // 音量 (0.0 - 1.0)
```

#### 3. 智能去重机制
- **文本相似度**: 基于编辑距离算法
- **时间间隔**: 防止过于频繁播报
- **强制模式**: 支持忽略检查的强制播报

---

## ⚡ 高级触觉反馈系统

### 技术基础
基于 Apple Core Haptics 框架的精细触觉控制系统。

### 实现细节

#### 1. 设备兼容性检查
```swift
private func setupHapticEngine() {
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
        print("❌ 设备不支持触觉反馈")
        return
    }
    
    do {
        engine = try CHHapticEngine()
        try engine?.start()
        supportsHaptics = true
    } catch {
        print("❌ 触觉引擎初始化失败: \(error)")
    }
}
```

#### 2. 精细强度控制
```swift
// 20级强度映射
func calculateIntensity(for distance: Float) -> Float {
    let clampedDistance = max(0.1, min(5.0, distance))
    return max(0.1, min(1.0, (5.1 - clampedDistance) / 5.0))
}

func calculateSharpness(for distance: Float) -> Float {
    let clampedDistance = max(0.1, min(5.0, distance))
    return max(0.1, min(1.0, (5.1 - clampedDistance) / 5.0))
}
```

#### 3. 触觉事件创建
```swift
let event = CHHapticEvent(
    eventType: .hapticTransient,
    parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
    ],
    relativeTime: 0
)
```

### 强度等级说明
| 距离范围 | 等级 | 强度值 | 用户感受 |
|----------|------|--------|----------|
| 4.8-5.0m | 1 | 0.10 | 极轻微感知 |
| 4.5-4.7m | 2 | 0.15 | 轻微感知 |
| ... | ... | ... | ... |
| 0.3-0.5m | 19 | 0.95 | 强烈警告 |
| 0.1-0.2m | 20 | 1.00 | 最强警告 |

---

## 🔄 系统集成与协调

### ARResourceCoordinator
统一管理所有 AR 相关资源和功能的协调器。

#### 主要职责
1. **资源管理**: 统一管理 ARSession 生命周期
2. **状态同步**: 确保各组件状态一致性
3. **性能优化**: 避免资源冲突和重复初始化
4. **错误处理**: 统一的错误处理和恢复机制

#### 核心方法
```swift
class ARResourceCoordinator {
    func startSession()     // 启动 AR 会话
    func stopSession()      // 停止 AR 会话
    func resetSettings()    // 重置所有设置
    func handleError()      // 错误处理
}
```

### 级联控制机制
实现主开关控制所有相关功能的级联行为。

```swift
// 级联启用逻辑
func enableLiDAR() {
    lidarEnabled = true
    hapticEnabled = true
    voiceEnabled = true
    cameraControlEnabled = true
    
    startARSession()
    print("✅ 所有 LiDAR 相关功能已启用")
}

// 级联禁用逻辑  
func disableLiDAR() {
    stopARSession()
    stopAllFeedback()
    
    lidarEnabled = false
    hapticEnabled = false
    voiceEnabled = false
    cameraControlEnabled = false
    
    resetState()
    print("✅ 所有 LiDAR 相关功能已禁用")
}
```

---

## 📊 性能优化策略

### 1. 计算资源优化
- **GPU 加速**: Vision 框架使用 GPU 进行特征提取
- **智能跳帧**: 相似度检测避免重复计算
- **异步处理**: 非阻塞的异步任务处理

### 2. 内存管理
- **对象复用**: 重用 AR 会话和处理对象
- **及时释放**: 主动释放不需要的资源
- **内存监控**: 监控内存使用情况

### 3. 电池优化
- **按需启用**: 功能按需启用，避免不必要的后台运行
- **智能降频**: 在不需要高频更新时降低处理频率
- **资源协调**: 避免多个功能同时占用相同资源

### 4. 用户体验优化
- **响应速度**: 优化触觉反馈的响应延迟
- **平滑过渡**: 距离变化时的平滑过渡效果
- **错误恢复**: 自动错误恢复和重试机制

---

**文档版本**: v1.0  
**最后更新**: 2025年5月
