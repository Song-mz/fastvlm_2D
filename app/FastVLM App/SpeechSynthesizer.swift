//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
import AVFoundation
import NaturalLanguage

/// 语速选项
public enum SpeechRate: String, CaseIterable, Identifiable {
    case slow = "慢速"
    case normal = "正常"
    case fast = "快速"

    public var id: String { rawValue }

    /// 获取对应的AVSpeechUtterance语速值
    var value: Float {
        switch self {
        case .slow:
            return 0.4
        case .normal:
            return 0.5
        case .fast:
            return 0.6
        }
    }
}

/// 封装AVSpeechSynthesizer功能的类，提供语音朗读服务
@available(*, unavailable, message: "Not available in Swift 6")
extension AVSpeechSynthesizer: @unchecked Sendable {}

class SpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {

    /// 单例实例
    static let shared = SpeechSynthesizer()

    /// 语音合成器
    private let synthesizer = AVSpeechSynthesizer()

    /// 当前是否正在朗读
    private(set) var isSpeaking = false

    /// 最近的描述文本
    private var lastDescription: String = ""

    /// 最后一次朗读的时间戳
    private var lastSpeechTime: Date = Date.distantPast

    /// 最小朗读间隔（秒）
    private var minSpeechInterval: TimeInterval = 3.0

    /// 相似度阈值（0-1之间，值越大表示需要更大差异才会触发新朗读）
    private var similarityThreshold: Double = 0.6

    /// 初始化
    private override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// 配置语音缓冲参数
    /// - Parameters:
    ///   - minInterval: 最小朗读间隔（秒）
    ///   - similarityThreshold: 相似度阈值（0-1）
    func configure(minInterval: TimeInterval, similarityThreshold: Double) {
        self.minSpeechInterval = minInterval
        self.similarityThreshold = similarityThreshold
    }

    /// 处理新的描述文本，智能决定是否朗读
    /// - Parameters:
    ///   - text: 要处理的文本
    ///   - language: 语言代码，默认为中文
    ///   - rate: 语速，默认为0.5
    ///   - pitchMultiplier: 音调，默认为1.0
    ///   - forceSpeak: 是否强制朗读，忽略相似度和时间间隔检查
    /// - Returns: 是否执行了朗读
    @discardableResult
    func processNewDescription(_ text: String, language: String = "zh-CN", rate: Float = 0.5, pitchMultiplier: Float = 1.0, forceSpeak: Bool = false) -> Bool {
        // 如果文本为空，不处理
        if text.isEmpty {
            return false
        }

        // 如果强制朗读，直接执行
        if forceSpeak {
            // 更新最后一次朗读的描述和时间
            lastDescription = text
            lastSpeechTime = Date()

            // 执行朗读
            speak(text, language: language, rate: rate, pitchMultiplier: pitchMultiplier)
            return true
        }

        // 计算与上一次描述的相似度
        let similarity = calculateSimilarity(between: text, and: lastDescription)

        // 当前时间
        let now = Date()

        // 距离上次朗读的时间间隔
        let timeSinceLastSpeech = now.timeIntervalSince(lastSpeechTime)

        // 决策逻辑：是否应该朗读新描述
        let shouldSpeak = shouldSpeakNewDescription(
            newDescription: text,
            similarity: similarity,
            timeSinceLastSpeech: timeSinceLastSpeech
        )

        if shouldSpeak {
            // 更新最后一次朗读的描述和时间
            lastDescription = text
            lastSpeechTime = now

            // 执行朗读
            speak(text, language: language, rate: rate, pitchMultiplier: pitchMultiplier)
            return true
        }

        return false
    }

    /// 计算两段文本的相似度
    private func calculateSimilarity(between text1: String, and text2: String) -> Double {
        // 如果任一文本为空，返回0（表示完全不同）
        if text1.isEmpty || text2.isEmpty {
            return 0.0
        }

        // 使用NaturalLanguage框架计算文本嵌入并比较相似度
        if #available(iOS 15.0, *) {
            if let embedding = NLEmbedding.sentenceEmbedding(for: .simplifiedChinese) {
                // 使用NLEmbedding的distance方法计算距离
                // distance值越小表示越相似，需要转换为相似度
                let distance = embedding.distance(between: text1, and: text2)
                // 将距离转换为相似度（距离越小，相似度越高）
                // 距离范围通常是0到2，将其映射到0到1的相似度范围
                return 1.0 - min(distance / 2.0, 1.0)
            }
        }

        // 备选方案：使用简单的词汇重叠率计算相似度
        let words1 = Set(text1.components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.components(separatedBy: .whitespacesAndNewlines))

        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count

        return union > 0 ? Double(intersection) / Double(union) : 0.0
    }

    /// 决策逻辑：是否应该朗读新描述
    private func shouldSpeakNewDescription(
        newDescription: String,
        similarity: Double,
        timeSinceLastSpeech: TimeInterval
    ) -> Bool {
        // 如果是首次描述，直接朗读
        if lastDescription.isEmpty {
            return true
        }

        // 如果描述内容变化显著（相似度低于阈值）
        let contentChangedSignificantly = similarity < similarityThreshold

        // 如果距离上次朗读已经过了足够长的时间
        let enoughTimeElapsed = timeSinceLastSpeech >= minSpeechInterval

        // 如果当前没有正在朗读，或者内容变化显著且已经过了最小间隔
        return (!isSpeaking && enoughTimeElapsed) ||
               (contentChangedSignificantly && enoughTimeElapsed)
    }

    /// 朗读指定文本
    /// - Parameters:
    ///   - text: 要朗读的文本
    ///   - language: 语言代码，默认为中文
    ///   - rate: 语速，默认为0.5
    ///   - pitchMultiplier: 音调，默认为1.0
    ///   - forceSpeak: 是否强制朗读，忽略当前朗读状态
    func speak(_ text: String, language: String = "zh-CN", rate: Float = 0.5, pitchMultiplier: Float = 1.0, forceSpeak: Bool = false) {
        // 如果强制朗读或当前没有在朗读，则执行朗读
        if forceSpeak || !isSpeaking {
            // 如果当前正在朗读，先停止
            if isSpeaking {
                stop()
            }

            // 创建语音朗读请求
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: language)
            utterance.rate = rate
            utterance.pitchMultiplier = pitchMultiplier
            utterance.volume = 1.0

            // 开始朗读
            synthesizer.speak(utterance)
            isSpeaking = true
        }
    }

    /// 停止朗读
    func stop() {
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }
    }

    /// 暂停朗读
    func pause() {
        if isSpeaking {
            synthesizer.pauseSpeaking(at: .immediate)
        }
    }

    /// 继续朗读
    func continueSpeaking() {
        if !synthesizer.isSpeaking && isSpeaking {
            synthesizer.continueSpeaking()
        }
    }

    /// 重置缓冲状态
    func reset() {
        lastDescription = ""
        lastSpeechTime = Date.distantPast
        stop()
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
    }
}
