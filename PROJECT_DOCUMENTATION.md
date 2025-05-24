# FastVLM 二次开发版本 - 项目文档

## 📋 项目概述

### 基础信息
本项目是基于 **Apple 官方开源 FastVLM 项目** 的二次开发版本。FastVLM 是 Apple 在 CVPR 2025 发表的高效视觉语言模型，专为移动设备优化，具有极快的首字生成时间（TTFT）和高效的视觉编码能力。

**原始 FastVLM 项目特点：**
- 🚀 **高效视觉编码**：使用 FastViTHD 混合视觉编码器，显著减少编码时间
- ⚡ **极快响应**：比 LLaVA-OneVision-0.5B 快 85 倍的首字生成时间
- 📱 **移动优化**：专为 iOS/macOS 设备设计，支持本地推理
- 🎯 **多尺寸模型**：提供 0.5B、1.5B、7B 三种规模的预训练模型

### 二次开发目的
本项目在原始 FastVLM 基础上，添加了多项增强功能，旨在：
1. **提升用户体验**：增加多模态交互能力（触觉、语音、距离感知）
2. **扩展应用场景**：支持无障碍访问和辅助功能
3. **优化性能**：减少重复处理，提高响应效率
4. **增强安全性**：添加距离感知和环境感知功能

⚠️ **重要声明**：这是一个 **个人测试开发项目**，仅用于学习和实验目的，不保证稳定性和生产环境适用性。

## 🆕 二次开发功能说明

### 1. LiDAR 距离感知系统
**功能描述：** 利用 iPhone/iPad 的 LiDAR 传感器实现实时距离检测和多级威胁预警。

**核心特性：**
- 🎯 **实时距离检测**：0.1-5.0 米范围内的精确距离测量
- ⚠️ **三级威胁预警**：高危（1米）、中危（2米）、低危（5米）可自定义阈值
- 🎮 **20级触觉反馈**：距离越近振动越强，提供精细的触觉感知
- 🔊 **语音距离播报**：实时语音提醒当前距离和威胁等级
- 📷 **智能摄像头控制**：LiDAR 启用时自动管理摄像头资源

**使用场景：**
- 视障人士导航辅助
- 狭小空间作业安全提醒
- 机器人避障系统开发
- 增强现实应用的空间感知

**级联控制行为：**
- 启用主开关 → 自动启用所有相关功能（触觉、语音、摄像头控制）
- 禁用主开关 → 自动禁用并重置所有相关功能

### 2. 图像相似度检测系统
**功能描述：** 使用 Vision 框架的特征提取技术，智能检测连续帧间的相似度，避免重复处理。

**核心特性：**
- 🧠 **智能特征提取**：基于 VNFeaturePrintObservation 的高精度图像特征分析
- ⏱️ **时间间隔控制**：可配置的最小处理间隔（默认 0.5 秒）
- 🎚️ **相似度阈值**：可调节的相似度判断标准（默认 0.7）
- 🔄 **三种检测模式**：
  - `imageOnly`：仅基于图像相似度
  - `textOnly`：仅基于文本相似度
  - `combined`：结合图像和文本相似度

**技术优势：**
- 减少不必要的 AI 推理，节省计算资源
- 提高电池续航时间
- 减少重复语音播报，改善用户体验

### 3. 智能语音合成系统
**功能描述：** 增强的文本转语音系统，具备智能去重和相似度检测功能。

**核心特性：**
- 🎤 **智能文本去重**：基于编辑距离算法的文本相似度计算
- ⏰ **时间间隔控制**：防止过于频繁的语音播报
- 🔊 **多语言支持**：支持中文、英文等多种语言
- 🎛️ **语音参数调节**：可调节语速、音调、音量
- 🚫 **强制播报模式**：支持忽略相似度检查的强制播报

**智能决策逻辑：**
```
是否播报 = (相似度 < 阈值) OR (时间间隔 > 最小间隔) OR 强制播报
```

### 4. 高级触觉反馈系统
**功能描述：** 基于 Core Haptics 的精细触觉反馈系统，提供 20 级强度的距离感知。

**核心特性：**
- 🎮 **20级强度映射**：距离 0.1-5.0 米线性映射到 20 个振动强度等级
- ⚡ **瞬时反馈**：使用 CHHapticEvent 实现低延迟触觉响应
- 🔧 **设备兼容性检查**：自动检测设备触觉支持能力
- 🧪 **测试功能**：内置触觉反馈测试工具

**强度计算公式：**
```swift
强度 = max(0.1, min(1.0, (5.1 - 距离) / 5.0))
锐度 = max(0.1, min(1.0, (5.1 - 距离) / 5.0))
```

## 📁 项目结构说明

### 主要目录结构
```
ml-fastvlm/
├── app/                          # iOS 应用程序
│   ├── FastVLM App/             # 主应用代码
│   │   ├── ContentView.swift    # 主界面视图
│   │   ├── LiDARDistanceSensor.swift      # LiDAR 距离感知
│   │   ├── ImageSimilarityDetector.swift  # 图像相似度检测
│   │   ├── SpeechSynthesizer.swift        # 语音合成系统
│   │   ├── HapticFeedbackManager.swift    # 触觉反馈管理
│   │   ├── ARResourceCoordinator.swift    # AR 资源协调器
│   │   └── LiDARDistanceView.swift        # LiDAR 设置界面
│   ├── FastVLM/                 # FastVLM 核心框架
│   ├── Video/                   # 视频处理框架
│   └── Configuration/           # 构建配置
├── llava/                       # Python LLaVA 训练代码
├── model_export/                # 模型导出工具
├── get_models.sh               # 模型下载脚本
└── pyproject.toml              # Python 项目配置
```

### Python 部分与 iOS App 关系
- **Python 部分**：用于模型训练、微调和导出
- **iOS App 部分**：使用导出的 MLX 格式模型进行本地推理
- **模型流程**：PyTorch 训练 → 导出为 MLX 格式 → iOS App 加载使用

### 关键配置文件
- `pyproject.toml`：Python 依赖和项目配置
- `app/Configuration/Build.xcconfig`：Xcode 构建配置
- `app/FastVLM App/Info.plist`：iOS 应用权限配置
- `.gitignore`：版本控制忽略规则

## 🚀 安装和使用指南

### 环境要求
**硬件要求：**
- iPhone/iPad：iOS 18.2+ 且支持 LiDAR（iPhone 12 Pro 及以上）
- Mac：macOS 15.2+ 且支持 Apple Silicon

**开发环境：**
- Xcode 15.0+
- Python 3.10+
- Git

### 1. 克隆项目
```bash
git clone <your-repository-url>
cd ml-fastvlm
```

### 2. Python 环境配置（可选）
如果需要训练或导出模型：
```bash
# 创建虚拟环境
conda create -n fastvlm python=3.10
conda activate fastvlm

# 安装依赖
pip install -e .
```

### 3. 下载预训练模型
```bash
# 使脚本可执行
chmod +x app/get_pretrained_mlx_model.sh

# 下载模型（选择一个尺寸）
app/get_pretrained_mlx_model.sh --model 0.5b --dest app/FastVLM/model
# 或者
app/get_pretrained_mlx_model.sh --model 1.5b --dest app/FastVLM/model
# 或者
app/get_pretrained_mlx_model.sh --model 7b --dest app/FastVLM/model
```

**模型选择建议：**
- **0.5B**：速度优先，适合实时交互
- **1.5B**：平衡选择，推荐日常使用
- **7B**：精度优先，适合复杂场景

### 4. iOS 应用编译和运行
1. 使用 Xcode 打开 `app/FastVLM.xcodeproj`
2. 选择目标设备（iPhone/iPad 或模拟器）
3. 设置开发团队和签名
4. 点击 Run 按钮编译并运行

**注意事项：**
- LiDAR 功能需要真实设备，模拟器不支持
- 首次运行需要授权摄像头和麦克风权限

## 🎯 功能使用说明

### LiDAR 距离感知使用教程

#### 1. 启用 LiDAR 功能
1. 打开应用，点击右上角设置按钮
2. 找到"LiDAR 距离感知"开关
3. 启用主开关（会自动启用所有相关功能）

#### 2. 功能配置
- **触觉反馈**：控制振动反馈的开启/关闭
- **语音播报**：控制距离语音提醒的开启/关闭
- **摄像头控制**：LiDAR 启用时是否自动停止摄像头
- **距离阈值**：自定义高危、中危、低危的距离阈值

#### 3. 使用体验
- 将设备对准前方物体
- 观察屏幕上的距离显示和威胁等级
- 感受不同距离下的振动强度变化
- 听取语音播报的距离信息

### 图像相似度检测配置

#### 检测模式选择
在代码中可配置三种模式：
```swift
model.similarityDetectionMode = .imageOnly    // 仅图像相似度
model.similarityDetectionMode = .textOnly     // 仅文本相似度
model.similarityDetectionMode = .combined     // 组合模式
```

#### 参数调节
```swift
ImageSimilarityDetector.shared.configure(
    minInterval: 0.5,    // 最小处理间隔（秒）
    threshold: 0.7       // 相似度阈值（0-1）
)
```

### 语音合成系统使用

#### 基本使用
```swift
// 智能播报（会检查相似度）
SpeechSynthesizer.shared.processNewDescription("描述文本")

// 强制播报（忽略相似度检查）
SpeechSynthesizer.shared.processNewDescription("描述文本", forceSpeak: true)
```

#### 参数配置
```swift
SpeechSynthesizer.shared.configure(
    minSpeechInterval: 3.0,     // 最小播报间隔
    similarityThreshold: 0.8    // 文本相似度阈值
)
```

## ⚠️ 开发状态声明

### 项目性质
这是一个 **个人实验性开发项目**，具有以下特点：

**✅ 已实现功能：**
- LiDAR 距离感知和多级预警
- 智能图像相似度检测
- 增强语音合成系统
- 精细触觉反馈控制
- 级联功能控制逻辑

**⚠️ 已知限制：**
- 仅在支持 LiDAR 的设备上完整可用
- 部分功能可能存在性能优化空间
- 错误处理机制有待完善
- 缺乏完整的单元测试覆盖

**🔧 开发状态：**
- **稳定性**：基本功能稳定，但可能存在边缘情况
- **性能**：在测试设备上表现良好，未进行大规模性能测试
- **兼容性**：主要针对 iOS 18.2+ 和支持 LiDAR 的设备

### 许可证限制
1. **仅限研究用途**：基于 Apple 模型许可证，整个项目仅限研究和学术用途
2. **禁止商业使用**：不得用于任何商业产品、服务或商业分发
3. **归属要求**：必须保留所有原始版权声明和许可证文件
4. **衍生作品标识**：必须清楚标明对原始项目的修改和增强

### 免责声明
1. **实验性质**：本项目为个人学习和实验项目，不保证生产环境的稳定性
2. **使用风险**：用户需自行承担使用风险，开发者不承担任何责任
3. **数据安全**：所有处理均在本地进行，不会上传用户数据
4. **设备兼容**：部分功能需要特定硬件支持，请确认设备兼容性
5. **许可证遵守**：用户必须严格遵守所有相关许可证条款

### 使用建议
- 🧪 **测试环境**：建议在安全的测试环境中使用
- 📱 **设备要求**：确保设备支持所需的硬件功能
- 🔄 **定期更新**：关注项目更新，及时获取修复和改进
- 💬 **反馈问题**：欢迎报告 bug 和提出改进建议

## 🔧 技术细节

### 主要技术栈
**iOS 开发：**
- Swift 5.9+
- SwiftUI
- ARKit (LiDAR)
- Vision Framework
- Core Haptics
- AVFoundation

**AI/ML 框架：**
- MLX (Apple Silicon 优化)
- Core ML
- Vision Framework

**Python 生态：**
- PyTorch
- Transformers
- LLaVA

### 关键实现原理

#### LiDAR 距离检测
```swift
// 使用 ARSession 和 ARWorldTrackingConfiguration
let configuration = ARWorldTrackingConfiguration()
configuration.frameSemantics = .sceneDepth
session.run(configuration)
```

#### 图像特征提取
```swift
// 使用 Vision 框架的特征提取
let request = VNGenerateImageFeaturePrintRequest()
let handler = VNImageRequestHandler(ciImage: ciImage)
try handler.perform([request])
```

#### 触觉反馈生成
```swift
// 使用 Core Haptics 创建精细触觉
let event = CHHapticEvent(
    eventType: .hapticTransient,
    parameters: [
        CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
        CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
    ],
    relativeTime: 0
)
```

### 故障排除指南

#### 常见问题

**1. LiDAR 功能不工作**
- 检查设备是否支持 LiDAR
- 确认 ARKit 权限已授权
- 重启应用或重新启用 LiDAR 开关

**2. 触觉反馈无响应**
- 检查设备是否支持 Core Haptics
- 确认系统触觉设置已启用
- 检查应用触觉权限

**3. 语音播报不工作**
- 检查麦克风权限
- 确认系统语音设置
- 检查音量设置

**4. 模型加载失败**
- 确认模型文件已正确下载
- 检查模型文件完整性
- 重新下载模型文件

#### 调试技巧
- 查看 Xcode 控制台日志
- 使用内置的诊断功能
- 检查 UserDefaults 设置状态
- 使用触觉反馈测试功能

---

**最后更新：** 2025年5月

**项目状态：** 实验性开发阶段

**联系方式：** 通过 GitHub Issues 反馈问题和建议
