# FastVLM 增强版 - 多模态交互视觉语言模型

> 基于 Apple 官方开源 FastVLM 项目的二次开发版本，添加了 LiDAR 距离感知、智能图像检测、语音交互等增强功能。

**[English](README_EN.md) | 中文**

[![iOS](https://img.shields.io/badge/iOS-18.2+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-See%20LICENSE-green.svg)](LICENSE)

## ✨ 主要特性

### 🎯 原始 FastVLM 功能
- **高效视觉编码**：使用 FastViTHD 混合视觉编码器
- **极快响应**：比传统模型快 85 倍的首字生成时间
- **移动优化**：专为 iOS/macOS 设备设计的本地推理
- **多尺寸模型**：0.5B、1.5B、7B 三种规模可选

### 🆕 增强功能
- **🎮 LiDAR 距离感知**：实时距离检测 + 20级触觉反馈 + 语音播报
- **🧠 智能图像检测**：基于 Vision 框架的相似度检测，避免重复处理
- **🔊 增强语音系统**：智能去重的文本转语音，支持多语言
- **⚡ 级联控制**：一键启用/禁用所有相关功能
- **🛡️ 安全预警**：三级距离威胁预警系统

## 🚀 快速开始

### 环境要求
- **设备**：iPhone 12 Pro+ 或 iPad Pro（需支持 LiDAR）
- **系统**：iOS 18.2+ / macOS 15.2+
- **开发**：Xcode 15.0+

### 安装步骤

1. **克隆项目**
```bash
git clone <your-repository-url>
cd ml-fastvlm
```

2. **下载模型**
```bash
chmod +x app/get_pretrained_mlx_model.sh
app/get_pretrained_mlx_model.sh --model 0.5b --dest app/FastVLM/model
```

3. **编译运行**
- 用 Xcode 打开 `app/FastVLM.xcodeproj`
- 选择目标设备并运行

## 🎯 功能演示

### LiDAR 距离感知
```
距离检测范围：0.1 - 5.0 米
威胁等级：高危(1m) | 中危(2m) | 低危(5m)
触觉反馈：20级强度映射
语音播报：实时距离提醒
```

### 智能图像检测
```
特征提取：Vision Framework
相似度阈值：可配置 (默认 0.7)
处理间隔：可配置 (默认 0.5s)
检测模式：图像 | 文本 | 组合
```

## 📱 使用指南

### 基础使用
1. 启动应用，授权摄像头和麦克风权限
2. 点击右上角设置按钮
3. 启用"LiDAR 距离感知"（会自动启用相关功能）
4. 将设备对准物体，体验距离感知和触觉反馈

### 高级配置
- **距离阈值**：自定义三级预警距离
- **触觉强度**：20级精细振动控制
- **语音设置**：多语言支持，可调语速音调
- **检测模式**：选择图像/文本/组合相似度检测

## 🔧 技术架构

### 核心组件
```
LiDARDistanceSensor     # LiDAR 距离感知核心
ImageSimilarityDetector # 图像相似度检测
SpeechSynthesizer      # 智能语音合成
HapticFeedbackManager  # 触觉反馈管理
ARResourceCoordinator  # AR 资源协调
```

### 技术栈
- **iOS**: Swift, SwiftUI, ARKit, Vision, Core Haptics
- **AI/ML**: MLX, Core ML, FastVLM
- **Python**: PyTorch, Transformers, LLaVA

## ⚠️ 重要声明

### 项目性质
这是一个 **个人实验性开发项目**，仅用于学习和测试目的。

### 🚨 许可证限制
- **仅限研究用途**: 基于 Apple 模型许可证，禁止商业使用
- **非商业项目**: 不得用于任何商业产品或服务
- **学术研究**: 适用于学术研究、技术学习、个人实验
- **完整许可证**: 请查看 LICENSE_ENHANCED 文件了解详细条款

### 使用限制
- ✅ 基本功能稳定，适合测试和学习
- ⚠️ 未经大规模生产环境验证
- 🔧 部分功能可能需要进一步优化
- 📱 完整功能需要支持 LiDAR 的设备
- 🚫 禁止商业使用和商业分发

### 免责声明
- 用户需自行承担使用风险
- 所有数据处理均在本地进行
- 不保证生产环境稳定性
- 必须遵守所有相关许可证条款
- 欢迎反馈问题和建议

## 📊 模型性能

| 模型 | 参数量 | TTFT | 推荐场景 |
|------|--------|------|----------|
| FastVLM-0.5B | 0.5B | 最快 | 实时交互 |
| FastVLM-1.5B | 1.5B | 平衡 | 日常使用 |
| FastVLM-7B | 7B | 最准 | 复杂场景 |

## 🤝 贡献指南

欢迎提交 Issue 和 Pull Request！

### 开发流程
1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 发起 Pull Request

### 问题反馈
- 🐛 Bug 报告：请提供详细的复现步骤
- 💡 功能建议：欢迎提出改进想法
- 📖 文档改进：帮助完善项目文档

## 📄 许可证

本项目包含多个组件，各自适用不同的许可证：
- [LICENSE](LICENSE) - Apple 原始代码许可证
- [LICENSE_MODEL](LICENSE_MODEL) - Apple 模型许可证 (仅限研究用途)
- [LICENSE_ENHANCED](LICENSE_ENHANCED) - 增强功能许可证 (MIT + 使用限制)

**重要**: 整个项目受 Apple 模型许可证约束，仅限研究和学术用途，禁止商业使用。

## 🙏 致谢

- **Apple FastVLM Team** - 原始 FastVLM 项目
- **LLaVA Project** - 训练框架支持
- **MLX Team** - Apple Silicon 优化框架

## 📞 联系方式

- **Issues**: [GitHub Issues](../../issues)
- **讨论**: [GitHub Discussions](../../discussions)

---

**📝 最后更新**: 2025年5月
