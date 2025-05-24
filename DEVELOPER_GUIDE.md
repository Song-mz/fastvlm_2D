# 开发者指南

## 🛠️ 开发环境配置

### 必需工具
- **Xcode**: 15.0+ (推荐最新版本)
- **iOS Deployment Target**: 18.2+
- **macOS**: 15.2+ (用于开发)
- **Git**: 版本控制
- **Python**: 3.10+ (可选，用于模型训练)

### 开发设备要求
- **测试设备**: iPhone 12 Pro+ 或 iPad Pro (支持 LiDAR)
- **模拟器限制**: LiDAR 功能无法在模拟器中测试

### 项目配置
1. 克隆项目后，确保所有子模块正确初始化
2. 在 Xcode 中设置开发团队和签名
3. 配置必要的权限和 entitlements

## 📁 代码架构说明

### 核心组件架构
```
FastVLM App/
├── Core/
│   ├── ContentView.swift           # 主界面控制器
│   └── FastVLMModel.swift         # 模型管理
├── LiDAR/
│   ├── LiDARDistanceSensor.swift  # LiDAR 核心功能
│   ├── ARResourceCoordinator.swift # AR 资源管理
│   └── LiDARDistanceView.swift    # LiDAR 设置界面
├── Detection/
│   └── ImageSimilarityDetector.swift # 图像相似度检测
├── Audio/
│   └── SpeechSynthesizer.swift    # 语音合成
├── Haptics/
│   └── HapticFeedbackManager.swift # 触觉反馈
└── Utils/
    └── LiDARDiagnosticTests.swift # 诊断工具
```

### 设计模式

#### 1. 单例模式 (Singleton)
```swift
// 用于全局共享的管理器
class LiDARDistanceSensor {
    static let shared = LiDARDistanceSensor()
    private init() {}
}

class ImageSimilarityDetector {
    static let shared = ImageSimilarityDetector()
    private init() {}
}
```

#### 2. 观察者模式 (Observer)
```swift
// 使用 Combine 框架进行状态通知
import Combine

class ARResourceCoordinator {
    let distanceUpdatePublisher = PassthroughSubject<(Float, DistanceThreatLevel), Never>()
    
    private func updateDistance(_ distance: Float) {
        distanceUpdatePublisher.send((distance, threatLevel))
    }
}
```

#### 3. 策略模式 (Strategy)
```swift
// 不同的相似度检测策略
enum SimilarityDetectionMode {
    case imageOnly
    case textOnly  
    case combined
}
```

## 🔧 关键功能实现

### LiDAR 距离检测实现

#### 1. ARSession 配置
```swift
private func setupARSession() {
    let configuration = ARWorldTrackingConfiguration()
    
    // 启用场景深度检测
    if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
        configuration.sceneReconstruction = .mesh
    }
    
    // 启用深度数据
    configuration.frameSemantics = .sceneDepth
    
    session.run(configuration)
}
```

#### 2. 深度数据处理
```swift
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    guard isEnabled,
          let depthData = frame.sceneDepth,
          let depthMap = depthData.depthMap else { return }
    
    // 获取中心点深度值
    let centerPoint = CGPoint(x: 0.5, y: 0.5)
    let distance = getDepthAtPoint(centerPoint, depthMap: depthMap)
    
    DispatchQueue.main.async {
        self.updateDistance(distance)
    }
}

private func getDepthAtPoint(_ point: CGPoint, depthMap: CVPixelBuffer) -> Float {
    CVPixelBufferLockBaseAddress(depthMap, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
    
    let width = CVPixelBufferGetWidth(depthMap)
    let height = CVPixelBufferGetHeight(depthMap)
    
    let x = Int(point.x * CGFloat(width))
    let y = Int(point.y * CGFloat(height))
    
    let baseAddress = CVPixelBufferGetBaseAddress(depthMap)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
    
    let buffer = baseAddress!.assumingMemoryBound(to: Float32.self)
    let index = y * (bytesPerRow / MemoryLayout<Float32>.size) + x
    
    return buffer[index]
}
```

### 图像相似度检测实现

#### 1. 特征提取
```swift
private func extractFeaturePrint(from imageBuffer: CVImageBuffer) async throws -> VNFeaturePrintObservation {
    let ciImage = CIImage(cvImageBuffer: imageBuffer)
    
    let request = VNGenerateImageFeaturePrintRequest()
    request.usesCPUOnly = false // 使用 GPU 加速
    
    let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
    try handler.perform([request])
    
    guard let observation = request.results?.first as? VNFeaturePrintObservation else {
        throw NSError(domain: "ImageSimilarityDetector", code: 1, 
                     userInfo: [NSLocalizedDescriptionKey: "无法提取图像特征"])
    }
    
    return observation
}
```

#### 2. 相似度计算
```swift
public func detectSimilarity(for imageBuffer: CVImageBuffer) async -> SimilarityResult {
    let now = Date()
    let timeSinceLastFeature = now.timeIntervalSince(lastFeatureTime)
    
    if lastFeaturePrint == nil || timeSinceLastFeature >= minFeatureInterval {
        if let currentFeaturePrint = try? await extractFeaturePrint(from: imageBuffer) {
            
            if let lastFeaturePrint = lastFeaturePrint {
                var distance: Float = 0
                try? lastFeaturePrint.computeDistance(&distance, to: currentFeaturePrint)
                
                let similarity = 1.0 - Double(distance)
                let shouldProcess = similarity < similarityThreshold
                
                self.lastFeaturePrint = currentFeaturePrint
                self.lastFeatureTime = now
                
                return SimilarityResult(
                    similarity: similarity,
                    shouldProcessNewFrame: shouldProcess,
                    isFirstFrame: false
                )
            }
        }
    }
    
    // 返回默认结果
    return SimilarityResult(similarity: 1.0, shouldProcessNewFrame: false, isFirstFrame: false)
}
```

### 触觉反馈实现

#### 1. Core Haptics 初始化
```swift
private func setupHapticEngine() {
    guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
        supportsHaptics = false
        return
    }
    
    do {
        engine = try CHHapticEngine()
        try engine?.start()
        supportsHaptics = true
        
        // 设置重置处理器
        engine?.resetHandler = { [weak self] in
            self?.restartHapticEngine()
        }
        
        // 设置停止处理器
        engine?.stoppedHandler = { [weak self] reason in
            self?.handleHapticEngineStop(reason: reason)
        }
        
    } catch {
        print("❌ 触觉引擎初始化失败: \(error)")
        supportsHaptics = false
    }
}
```

#### 2. 触觉事件生成
```swift
func playHapticFeedback(forDistance distance: Float) {
    guard supportsHaptics, let engine = engine else { return }
    
    let intensity = calculateIntensity(for: distance)
    let sharpness = calculateSharpness(for: distance)
    
    do {
        try engine.start()
        
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )
        
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        let player = try engine.makePlayer(with: pattern)
        try player.start(atTime: CHHapticTimeImmediate)
        
    } catch {
        print("❌ 播放触觉反馈失败: \(error)")
    }
}
```

## 🧪 测试和调试

### 单元测试
```swift
import XCTest
@testable import FastVLM_App

class LiDARDistanceSensorTests: XCTestCase {
    
    func testDistanceThresholds() {
        let sensor = LiDARDistanceSensor.shared
        
        // 测试高危阈值
        sensor.highThreatThreshold = 1.0
        XCTAssertEqual(sensor.getThreatLevel(for: 0.5), .high)
        
        // 测试中危阈值
        sensor.mediumThreatThreshold = 2.0
        XCTAssertEqual(sensor.getThreatLevel(for: 1.5), .medium)
        
        // 测试低危阈值
        sensor.lowThreatThreshold = 5.0
        XCTAssertEqual(sensor.getThreatLevel(for: 3.0), .low)
    }
}
```

### 调试技巧

#### 1. 日志系统
```swift
// 使用统一的日志格式
func logLiDAR(_ message: String, level: LogLevel = .info) {
    let timestamp = DateFormatter.timestamp.string(from: Date())
    print("[\(timestamp)] [LiDAR] [\(level.rawValue)] \(message)")
}

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}
```

#### 2. 性能监控
```swift
// 监控 AR 会话性能
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    let startTime = CFAbsoluteTimeGetCurrent()
    
    // 处理逻辑
    processFrame(frame)
    
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    if timeElapsed > 0.016 { // 超过 16ms (60fps)
        print("⚠️ 帧处理耗时过长: \(timeElapsed * 1000)ms")
    }
}
```

#### 3. 内存监控
```swift
// 监控内存使用
func logMemoryUsage() {
    let info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    
    if kerr == KERN_SUCCESS {
        let memoryUsage = info.resident_size / 1024 / 1024 // MB
        print("📊 内存使用: \(memoryUsage) MB")
    }
}
```

## 🔧 常见问题解决

### 1. LiDAR 不工作
**问题**: LiDAR 距离检测无响应

**解决步骤**:
```swift
// 检查设备支持
guard ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
    print("❌ 设备不支持 LiDAR")
    return
}

// 检查权限
guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
    print("❌ 摄像头权限未授权")
    return
}

// 重置 AR 会话
session.pause()
session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
```

### 2. 触觉反馈无效
**问题**: 触觉反馈不工作

**解决步骤**:
```swift
// 检查设备支持
guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
    print("❌ 设备不支持触觉反馈")
    return
}

// 检查系统设置
// 用户需要在设置中启用触觉反馈

// 重新初始化引擎
engine?.stop()
engine = nil
setupHapticEngine()
```

### 3. 性能问题
**问题**: 应用运行缓慢或卡顿

**优化策略**:
```swift
// 1. 降低处理频率
private var lastProcessTime = Date()
private let minProcessInterval: TimeInterval = 0.1 // 100ms

func processFrame(_ frame: ARFrame) {
    let now = Date()
    guard now.timeIntervalSince(lastProcessTime) >= minProcessInterval else {
        return
    }
    lastProcessTime = now
    
    // 处理逻辑
}

// 2. 异步处理
DispatchQueue.global(qos: .userInitiated).async {
    // 耗时操作
    let result = heavyComputation()
    
    DispatchQueue.main.async {
        // 更新 UI
        self.updateUI(with: result)
    }
}
```

## 📚 最佳实践

### 1. 资源管理
- 及时释放不需要的 AR 会话
- 使用弱引用避免循环引用
- 在应用进入后台时暂停资源密集型操作

### 2. 用户体验
- 提供清晰的功能状态指示
- 实现平滑的过渡动画
- 添加适当的错误提示和恢复机制

### 3. 性能优化
- 使用异步处理避免阻塞主线程
- 实现智能的处理频率控制
- 监控内存和 CPU 使用情况

### 4. 代码质量
- 遵循 Swift 编码规范
- 添加充分的注释和文档
- 实现全面的错误处理

---

**开发者指南版本**: v1.0  
**最后更新**: 2025年5月  
**维护者**: FastVLM 增强版开发团队
