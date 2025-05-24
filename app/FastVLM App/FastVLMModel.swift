//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import CoreImage
import FastVLM
import Foundation
import MLX
import MLXLMCommon
import MLXRandom
import MLXVLM
import AVFoundation

@Observable
@MainActor
class FastVLMModel {

    public var running = false
    public var modelInfo = ""
    public var output = ""
    public var promptTime: String = ""

    /// 是否启用语音朗读功能
    public var textToSpeechEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "textToSpeechEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "textToSpeechEnabled")
            // 如果禁用了语音朗读，停止当前朗读
            if !newValue {
                SpeechSynthesizer.shared.stop()
            } else {
                // 如果启用了语音朗读，配置语音缓冲参数
                configureSpeechBuffer()
            }
        }
    }

    /// 语音朗读语速
    public var speechRate: SpeechRate {
        get {
            if let savedRateString = UserDefaults.standard.string(forKey: "speechRate"),
               let savedRate = SpeechRate(rawValue: savedRateString) {
                return savedRate
            }
            return .normal // 默认使用正常语速
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "speechRate")
            // 如果当前正在朗读，停止当前朗读并使用新的语速重新开始
            if SpeechSynthesizer.shared.isSpeaking && !output.isEmpty {
                SpeechSynthesizer.shared.stop()
                SpeechSynthesizer.shared.speak(output, rate: newValue.value)
            }
        }
    }

    /// 最小朗读间隔（秒）
    public var speechInterval: TimeInterval {
        get {
            let savedInterval = UserDefaults.standard.double(forKey: "speechInterval")
            return savedInterval > 0 ? savedInterval : 3.0 // 默认3秒
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "speechInterval")
            configureSpeechBuffer()
        }
    }

    /// 语音相似度阈值（0-1之间）
    public var speechSimilarityThreshold: Double {
        get {
            let savedThreshold = UserDefaults.standard.double(forKey: "speechSimilarityThreshold")
            return savedThreshold > 0 ? savedThreshold : 0.6 // 默认0.6
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "speechSimilarityThreshold")
            configureSpeechBuffer()
        }
    }

    /// 是否启用图像相似度检测
    public var imageBasedSimilarityEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "imageBasedSimilarityEnabled")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "imageBasedSimilarityEnabled")
            if !newValue {
                // 如果禁用了图像相似度检测，重置检测器状态
                ImageSimilarityDetector.shared.reset()
            }
        }
    }

    /// 图像相似度阈值（0-1之间）
    public var imageSimilarityThreshold: Double {
        get {
            let savedThreshold = UserDefaults.standard.double(forKey: "imageSimilarityThreshold")
            return savedThreshold > 0 ? savedThreshold : 0.7 // 默认0.7
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "imageSimilarityThreshold")
            configureImageSimilarityDetector()
        }
    }

    /// 图像特征提取最小间隔（秒）
    public var imageFeatureInterval: TimeInterval {
        get {
            let savedInterval = UserDefaults.standard.double(forKey: "imageFeatureInterval")
            return savedInterval > 0 ? savedInterval : 0.5 // 默认0.5秒
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "imageFeatureInterval")
            configureImageSimilarityDetector()
        }
    }

    /// 相似度检测模式
    public enum SimilarityDetectionMode: String, CaseIterable, Identifiable {
        case textOnly = "仅文本相似度"
        case imageOnly = "仅图像相似度"
        case combined = "文本和图像结合"

        public var id: String { rawValue }
    }

    /// 相似度检测模式
    public var similarityDetectionMode: SimilarityDetectionMode {
        get {
            if let savedModeString = UserDefaults.standard.string(forKey: "similarityDetectionMode"),
               let savedMode = SimilarityDetectionMode(rawValue: savedModeString) {
                return savedMode
            }
            return .textOnly // 默认使用文本相似度
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "similarityDetectionMode")
        }
    }

    /// 配置语音缓冲参数
    private func configureSpeechBuffer() {
        SpeechSynthesizer.shared.configure(
            minInterval: speechInterval,
            similarityThreshold: speechSimilarityThreshold
        )
    }

    /// 配置图像相似度检测器
    private func configureImageSimilarityDetector() {
        ImageSimilarityDetector.shared.configure(
            minInterval: imageFeatureInterval,
            threshold: imageSimilarityThreshold
        )
    }

    enum LoadState {
        case idle
        case loaded(ModelContainer)
    }

    private let modelConfiguration = FastVLM.modelConfiguration

    /// parameters controlling the output
    let generateParameters = GenerateParameters(temperature: 0.0)
    let maxTokens = 240

    /// update the display every N tokens -- 4 looks like it updates continuously
    /// and is low overhead.  observed ~15% reduction in tokens/s when updating
    /// on every token
    let displayEveryNTokens = 4

    private var loadState = LoadState.idle
    private var currentTask: Task<Void, Never>?

    enum EvaluationState: String, CaseIterable {
        case idle = "空闲"
        case processingPrompt = "处理提示词中"
        case generatingResponse = "生成回复中"
    }

    public var evaluationState = EvaluationState.idle

    public init() {
        FastVLM.register(modelFactory: VLMModelFactory.shared)

        // 初始化语音缓冲配置
        configureSpeechBuffer()

        // 初始化图像相似度检测器配置
        configureImageSimilarityDetector()

        // 默认启用图像相似度检测，并设置为仅图像模式
        if !UserDefaults.standard.bool(forKey: "imageBasedSimilarityInitialized") {
            UserDefaults.standard.set(true, forKey: "imageBasedSimilarityEnabled")
            UserDefaults.standard.set(true, forKey: "imageBasedSimilarityInitialized")
            UserDefaults.standard.set(SimilarityDetectionMode.imageOnly.rawValue, forKey: "similarityDetectionMode")
        }
    }

    private func _load() async throws -> ModelContainer {
        switch loadState {
        case .idle:
            // limit the buffer cache
            MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)

            let modelContainer = try await VLMModelFactory.shared.loadContainer(
                configuration: modelConfiguration
            ) {
                [modelConfiguration] progress in
                Task { @MainActor in
                    self.modelInfo =
                        "下载中 \(modelConfiguration.name): \(Int(progress.fractionCompleted * 100))%"
                }
            }
            self.modelInfo = "已加载"
            loadState = .loaded(modelContainer)
            return modelContainer

        case .loaded(let modelContainer):
            return modelContainer
        }
    }

    public func load() async {
        do {
            _ = try await _load()
        } catch {
            self.modelInfo = "加载模型错误: \(error)"
        }
    }

    public func generate(_ userInput: UserInput) async -> Task<Void, Never> {
        if let currentTask, running {
            return currentTask
        }

        running = true

        // Cancel any existing task
        currentTask?.cancel()

        // Create new task and store reference
        let task = Task {
            do {
                let modelContainer = try await _load()

                // each time you generate you will get something new
                MLXRandom.seed(UInt64(Date.timeIntervalSinceReferenceDate * 1000))

                // Check if task was cancelled
                if Task.isCancelled { return }

                let result = try await modelContainer.perform { context in
                    // Measure the time it takes to prepare the input

                    Task { @MainActor in
                        evaluationState = .processingPrompt
                    }

                    let llmStart = Date()
                    let input = try await context.processor.prepare(input: userInput)

                    var seenFirstToken = false

                    // FastVLM generates the output
                    let result = try MLXLMCommon.generate(
                        input: input, parameters: generateParameters, context: context
                    ) { tokens in
                        // Check if task was cancelled
                        if Task.isCancelled {
                            return .stop
                        }

                        if !seenFirstToken {
                            seenFirstToken = true

                            // produced first token, update the time to first token,
                            // the processing state and start displaying the text
                            let llmDuration = Date().timeIntervalSince(llmStart)
                            let text = context.tokenizer.decode(tokens: tokens)
                            Task { @MainActor in
                                evaluationState = .generatingResponse
                                self.output = text
                                self.promptTime = "\(Int(llmDuration * 1000)) ms"
                            }
                        }

                        // Show the text in the view as it generates
                        if tokens.count % displayEveryNTokens == 0 {
                            let text = context.tokenizer.decode(tokens: tokens)
                            Task { @MainActor in
                                self.output = text
                            }
                        }

                        if tokens.count >= maxTokens {
                            return .stop
                        } else {
                            return .more
                        }
                    }

                    // Return the duration of the LLM and the result
                    return result
                }

                // Check if task was cancelled before updating UI
                if !Task.isCancelled {
                    // 如果启用了语音朗读，立即停止当前朗读
                    if self.textToSpeechEnabled {
                        // 无论当前是否正在朗读，都先停止
                        SpeechSynthesizer.shared.stop()
                    }

                    // 更新UI显示的文本
                    self.output = result.output

                    // 如果启用了语音朗读，立即开始朗读新文本
                    if self.textToSpeechEnabled {
                        // 直接使用speak方法而不是processNewDescription，确保立即朗读
                        SpeechSynthesizer.shared.speak(
                            result.output,
                            rate: self.speechRate.value
                        )
                    }
                }

            } catch {
                if !Task.isCancelled {
                    output = "失败: \(error)"
                }
            }

            if evaluationState == .generatingResponse {
                evaluationState = .idle
            }

            running = false
        }

        currentTask = task
        return task
    }

    public func cancel() {
        currentTask?.cancel()
        currentTask = nil
        running = false
        output = ""
        promptTime = ""

        // 停止语音朗读并重置缓冲状态
        SpeechSynthesizer.shared.reset()
    }
}
