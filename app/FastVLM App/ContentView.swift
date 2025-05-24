//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import AVFoundation
import MLXLMCommon
import SwiftUI
import Video
import Vision
import ARKit
import CoreHaptics

// support swift 6
extension CVImageBuffer: @unchecked @retroactive Sendable {}
extension CMSampleBuffer: @unchecked @retroactive Sendable {}

// delay between frames -- controls the frame rate of the updates
let FRAME_DELAY = Duration.milliseconds(1)

struct ContentView: View {
    @State private var camera = CameraController()
    @State private var model = FastVLMModel()

    /// stream of frames -> VideoFrameView, see distributeVideoFrames
    @State private var framesToDisplay: AsyncStream<CVImageBuffer>?

    @State private var prompt = "用中文描述这张图片。"
    @State private var promptSuffix = "输出应简洁，不超过15个字。"

    @State private var isShowingInfo: Bool = false
    @State private var isShowingSpeechSettings: Bool = false

    @State private var selectedCameraType: CameraType = .continuous
    @State private var isEditingPrompt: Bool = false

    var toolbarItemPlacement: ToolbarItemPlacement {
        var placement: ToolbarItemPlacement = .navigation
        #if os(iOS)
        placement = .topBarLeading
        #endif
        return placement
    }

    var statusTextColor : Color {
        return model.evaluationState == .processingPrompt ? .black : .white
    }

    var statusBackgroundColor : Color {
        switch model.evaluationState {
        case .idle:
            return .gray
        case .generatingResponse:
            return .green
        case .processingPrompt:
            return .yellow
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 10.0) {
                        Picker("相机类型", selection: $selectedCameraType) {
                            ForEach(CameraType.allCases, id: \.self) { cameraType in
                                Text(cameraType.rawValue == "continuous" ? "连续模式" : "单帧模式").tag(cameraType)
                            }
                        }
                        // Prevent macOS from adding a text label for the picker
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .onChange(of: selectedCameraType) { _, _ in
                            // Cancel any in-flight requests when switching modes
                            model.cancel()
                        }

                        if let framesToDisplay {
                            VideoFrameView(
                                frames: framesToDisplay,
                                cameraType: selectedCameraType,
                                action: { frame in
                                    processSingleFrame(frame)
                                })
                                // Because we're using the AVCaptureSession preset
                                // `.vga640x480`, we can assume this aspect ratio
                                .aspectRatio(4/3, contentMode: .fit)
                                #if os(macOS)
                                .frame(maxWidth: 750)
                                #endif
                                .overlay(alignment: .top) {
                                    if !model.promptTime.isEmpty {
                                        Text("首字时间 \(model.promptTime)")
                                            .font(.caption)
                                            .foregroundStyle(.white)
                                            .monospaced()
                                            .padding(.vertical, 4.0)
                                            .padding(.horizontal, 6.0)
                                            .background(alignment: .center) {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.black.opacity(0.6))
                                            }
                                            .padding(.top)
                                    }
                                }
                                #if !os(macOS)
                                .overlay(alignment: .topTrailing) {
                                    CameraControlsView(
                                        backCamera: $camera.backCamera,
                                        device: $camera.device,
                                        devices: $camera.devices)
                                    .padding()
                                }
                                #endif
                                .overlay(alignment: .bottom) {
                                    if selectedCameraType == .continuous {
                                        Group {
                                            if model.evaluationState == .processingPrompt {
                                                HStack {
                                                    ProgressView()
                                                        .tint(self.statusTextColor)
                                                        .controlSize(.small)

                                                    Text(model.evaluationState.rawValue)
                                                }
                                            } else if model.evaluationState == .idle {
                                                HStack(spacing: 6.0) {
                                                    Image(systemName: "clock.fill")
                                                        .font(.caption)

                                                    Text(model.evaluationState.rawValue)
                                                }
                                            }
                                            else {
                                                // I'm manually tweaking the spacing to
                                                // better match the spacing with ProgressView
                                                HStack(spacing: 6.0) {
                                                    Image(systemName: "lightbulb.fill")
                                                        .font(.caption)

                                                    Text(model.evaluationState.rawValue)
                                                }
                                            }
                                        }
                                        .foregroundStyle(self.statusTextColor)
                                        .font(.caption)
                                        .bold()
                                        .padding(.vertical, 6.0)
                                        .padding(.horizontal, 8.0)
                                        .background(self.statusBackgroundColor)
                                        .clipShape(.capsule)
                                        .padding(.bottom)
                                    }
                                }
                                #if os(macOS)
                                .frame(maxWidth: .infinity)
                                .frame(minWidth: 500)
                                .frame(minHeight: 375)
                                #endif
                        }
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

                promptSections

                Section {
                    if model.output.isEmpty && model.running {
                        ProgressView()
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 10) {
                            ScrollView {
                                Text(model.output)
                                    .foregroundStyle(isEditingPrompt ? .secondary : .primary)
                                    .textSelection(.enabled)
                                    #if os(macOS)
                                    .font(.headline)
                                    .fontWeight(.regular)
                                    #endif
                            }
                            .frame(minHeight: 50.0, maxHeight: 200.0)

                            // 功能控制区域
                            VStack(spacing: 12) {
                                // 语音朗读控制区域
                                VStack(spacing: 8) {
                                    // 语音朗读开关
                                    Toggle(isOn: $model.textToSpeechEnabled) {
                                        HStack {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .foregroundColor(.accentColor)
                                            Text("语音朗读")
                                                .font(.subheadline)
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))

                                    // 语速选择（仅在启用语音朗读时显示）
                                    if model.textToSpeechEnabled {
                                        HStack {
                                            Text("语速：")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)

                                            Picker("语速", selection: $model.speechRate) {
                                                ForEach(SpeechRate.allCases) { rate in
                                                    Text(rate.rawValue).tag(rate)
                                                }
                                            }
                                            .pickerStyle(.segmented)
                                            .labelsHidden()
                                        }
                                        .padding(.top, 2)
                                        .transition(.opacity)

                                        // 高级设置按钮
                                        Button {
                                            isShowingSpeechSettings.toggle()
                                        } label: {
                                            HStack {
                                                Image(systemName: "slider.horizontal.3")
                                                    .foregroundColor(.accentColor)
                                                Text("高级设置")
                                                    .font(.subheadline)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .buttonStyle(.borderless)
                                        .padding(.top, 4)
                                        .transition(.opacity)
                                    }
                                }
                                .padding(.horizontal, 4)
                                .animation(.easeInOut(duration: 0.2), value: model.textToSpeechEnabled)

                                // 分隔线
                                Divider()
                                    .padding(.vertical, 4)

                                // LiDAR距离感知控制区域
                                LiDARDistanceView()

                                // 摄像头状态提示
                                if LiDARDistanceSensor.shared.isEnabled {
                                    HStack {
                                        Image(systemName: LiDARDistanceSensor.shared.cameraControlEnabled ? "camera.fill" : "camera.on.rectangle.fill")
                                            .foregroundColor(LiDARDistanceSensor.shared.cameraControlEnabled ? .orange : .green)
                                        Text(LiDARDistanceSensor.shared.cameraControlEnabled ?
                                             "摄像头已停止以启用LiDAR距离感知" :
                                             "LiDAR与摄像头并行运行模式")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 8)
                                    .padding(.horizontal, 4)
                                }
                            }
                            #if os(macOS)
                            .padding(.bottom, 8)
                            #endif

                            // 语音朗读高级设置面板
                            .sheet(isPresented: $isShowingSpeechSettings) {
                                NavigationStack {
                                    Form {
                                        // 相似度检测模式选择
                                        Section(header: Text("相似度检测模式")) {
                                            Picker("检测模式", selection: $model.similarityDetectionMode) {
                                                ForEach(FastVLMModel.SimilarityDetectionMode.allCases) { mode in
                                                    Text(mode.rawValue).tag(mode)
                                                }
                                            }
                                            .pickerStyle(.segmented)
                                            .padding(.vertical, 4)
                                        }

                                        // 文本相似度设置
                                        if model.similarityDetectionMode != .imageOnly {
                                            Section(header: Text("文本相似度设置")) {
                                                // 最小朗读间隔设置
                                                VStack(alignment: .leading) {
                                                    Text("最小朗读间隔：\(Int(model.speechInterval))秒")
                                                        .font(.subheadline)

                                                    Slider(value: Binding(
                                                        get: { model.speechInterval },
                                                        set: { model.speechInterval = $0 }
                                                    ), in: 1...10, step: 1)
                                                    .accentColor(.accentColor)
                                                }
                                                .padding(.vertical, 4)

                                                // 文本相似度阈值设置
                                                VStack(alignment: .leading) {
                                                    Text("文本相似度阈值：\(Int(model.speechSimilarityThreshold * 100))%")
                                                        .font(.subheadline)

                                                    Slider(value: Binding(
                                                        get: { model.speechSimilarityThreshold },
                                                        set: { model.speechSimilarityThreshold = $0 }
                                                    ), in: 0.1...0.9, step: 0.05)
                                                    .accentColor(.accentColor)
                                                }
                                                .padding(.vertical, 4)
                                            }
                                        }

                                        // 图像相似度设置
                                        if model.similarityDetectionMode != .textOnly {
                                            Section(header: Text("图像相似度设置")) {
                                                // 图像相似度阈值设置
                                                VStack(alignment: .leading) {
                                                    Text("图像相似度阈值：\(Int(model.imageSimilarityThreshold * 100))%")
                                                        .font(.subheadline)

                                                    Slider(value: Binding(
                                                        get: { model.imageSimilarityThreshold },
                                                        set: { model.imageSimilarityThreshold = $0 }
                                                    ), in: 0.1...0.9, step: 0.05)
                                                    .accentColor(.accentColor)
                                                }
                                                .padding(.vertical, 4)

                                                // 图像特征提取间隔设置
                                                VStack(alignment: .leading) {
                                                    Text("特征提取间隔：\(String(format: "%.1f", model.imageFeatureInterval))秒")
                                                        .font(.subheadline)

                                                    Slider(value: Binding(
                                                        get: { model.imageFeatureInterval },
                                                        set: { model.imageFeatureInterval = $0 }
                                                    ), in: 0.1...2.0, step: 0.1)
                                                    .accentColor(.accentColor)
                                                }
                                                .padding(.vertical, 4)
                                            }
                                        }

                                        Section(header: Text("说明")) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("检测模式：选择使用文本相似度、图像相似度或两者结合来判断是否需要更新朗读。")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)

                                                if model.similarityDetectionMode != .imageOnly {
                                                    Text("文本相似度阈值：决定新旧描述的差异程度需要多大才会触发新的朗读。较高的值意味着需要更大的差异。")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)

                                                    Text("最小朗读间隔：两次朗读之间的最小时间间隔，较长的间隔可减少频繁打断。")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }

                                                if model.similarityDetectionMode != .textOnly {
                                                    Text("图像相似度阈值：决定新旧图像的差异程度需要多大才会触发新的朗读。较高的值意味着需要更大的差异。")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)

                                                    Text("特征提取间隔：两次图像特征提取之间的最小时间间隔，较长的间隔可减少CPU使用。")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                        }
                                    }
                                    .navigationTitle("语音朗读高级设置")
                                    .navigationBarTitleDisplayMode(.inline)
                                    .toolbar {
                                        ToolbarItem(placement: .confirmationAction) {
                                            Button("完成") {
                                                isShowingSpeechSettings = false
                                            }
                                        }
                                    }
                                }
                                .presentationDetents([.medium])
                            }
                        }
                    }
                } header: {
                    Text("回复")
                        #if os(macOS)
                        .font(.headline)
                        .padding(.bottom, 2.0)
                        #endif
                }

                #if os(macOS)
                Spacer()
                #endif
            }

            #if os(iOS)
            .listSectionSpacing(0)
            #elseif os(macOS)
            .padding()
            #endif
            .task {
                camera.start()
                // 设置LiDAR传感器的摄像头控制器引用
                LiDARDistanceSensor.shared.setCameraController(camera)
            }
            .task {
                await model.load()
            }

            #if !os(macOS)
            .onAppear {
                // Prevent the screen from dimming or sleeping due to inactivity
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                // Resumes normal idle timer behavior
                UIApplication.shared.isIdleTimerDisabled = false
            }
            #endif

            // task to distribute video frames -- this will cancel
            // and restart when the view is on/off screen.  note: it is
            // important that this is here (attached to the VideoFrameView)
            // rather than the outer view because this has the correct lifecycle
            .task {
                if Task.isCancelled {
                    return
                }

                await distributeVideoFrames()
            }

            .navigationTitle("FastVLM视觉语言模型")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: toolbarItemPlacement) {
                    Button {
                        isShowingInfo.toggle()
                    }
                    label: {
                        Image(systemName: "info.circle")
                    }
                }



                ToolbarItem(placement: .primaryAction) {
                    if isEditingPrompt {
                        Button {
                            isEditingPrompt.toggle()
                        }
                        label: {
                            Text("完成")
                                .fontWeight(.bold)
                        }
                    }
                    else {
                        Menu {
                            Button("描述图像") {
                                prompt = "用中文描述这张图片。"
                                promptSuffix = "输出应简洁，不超过15个字。"
                            }
                            Button("面部表情") {
                                prompt = "这个人的面部表情是什么？"
                                promptSuffix = "只输出一两个词。"
                            }
                            Button("阅读文字") {
                                prompt = "图像中写了什么文字？"
                                promptSuffix = "只输出图像中的文字。"
                            }
                            #if !os(macOS)
                            Button("自定义...") {
                                isEditingPrompt.toggle()
                            }
                            #endif
                        } label: { Text("提示词") }
                    }
                }
            }
            .sheet(isPresented: $isShowingInfo) {
                InfoView()
            }
        }
    }

    var promptSummary: some View {
        Section("提示词") {
            VStack(alignment: .leading, spacing: 4.0) {
                let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedPrompt.isEmpty {
                    Text(trimmedPrompt)
                        .foregroundStyle(.secondary)
                }

                let trimmedSuffix = promptSuffix.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedSuffix.isEmpty {
                    Text(trimmedSuffix)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    var promptForm: some View {
        Group {
            #if os(iOS)
            Section("提示词") {
                TextEditor(text: $prompt)
                    .frame(minHeight: 38)
            }

            Section("提示词后缀") {
                TextEditor(text: $promptSuffix)
                    .frame(minHeight: 38)
            }
            #elseif os(macOS)
            Section {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        Text("提示词")
                            .font(.headline)

                        TextEditor(text: $prompt)
                            .frame(height: 38)
                            .padding(.horizontal, 8.0)
                            .padding(.vertical, 10.0)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(10.0)
                    }

                    VStack(alignment: .leading) {
                        Text("提示词后缀")
                            .font(.headline)

                        TextEditor(text: $promptSuffix)
                            .frame(height: 38)
                            .padding(.horizontal, 8.0)
                            .padding(.vertical, 10.0)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(10.0)
                    }
                }
            }
            .padding(.vertical)
            #endif
        }
    }

    var promptSections: some View {
        Group {
            #if os(iOS)
            if isEditingPrompt {
                promptForm
            }
            else {
                promptSummary
            }
            #elseif os(macOS)
            promptForm
            #endif
        }
    }

    func analyzeVideoFrames(_ frames: AsyncStream<CVImageBuffer>) async {
        for await frame in frames {
            // 如果启用了图像相似度检测且不是仅使用文本相似度模式
            if model.similarityDetectionMode != .textOnly {
                // 检测图像相似度
                let similarityResult = await ImageSimilarityDetector.shared.detectSimilarity(for: frame)

                // 根据检测模式和结果决定是否处理新帧
                if model.similarityDetectionMode == .imageOnly {
                    // 仅使用图像相似度
                    if !similarityResult.shouldProcessNewFrame && !similarityResult.isFirstFrame {
                        // 如果图像相似度高且不是首帧，跳过处理
                        continue
                    }
                } else if model.similarityDetectionMode == .combined {
                    // 结合图像和文本相似度，先检查图像
                    if !similarityResult.shouldProcessNewFrame && !similarityResult.isFirstFrame {
                        // 如果图像相似度高且不是首帧，跳过处理
                        continue
                    }
                    // 如果图像相似度低，会继续处理，文本相似度会在语音合成时检查
                }
            }

            let userInput = UserInput(
                prompt: .text("\(prompt) \(promptSuffix)"),
                images: [.ciImage(CIImage(cvPixelBuffer: frame))]
            )

            // generate output for a frame and wait for generation to complete
            let t = await model.generate(userInput)
            _ = await t.result

            do {
                try await Task.sleep(for: FRAME_DELAY)
            } catch { return }
        }
    }

    func distributeVideoFrames() async {
        // attach a stream to the camera -- this code will read this
        let frames = AsyncStream<CMSampleBuffer>(bufferingPolicy: .bufferingNewest(1)) {
            camera.attach(continuation: $0)
        }

        let (framesToDisplay, framesToDisplayContinuation) = AsyncStream.makeStream(
            of: CVImageBuffer.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        self.framesToDisplay = framesToDisplay

        // Only create analysis stream if in continuous mode
        let (framesToAnalyze, framesToAnalyzeContinuation) = AsyncStream.makeStream(
            of: CVImageBuffer.self,
            bufferingPolicy: .bufferingNewest(1)
        )

        // set up structured tasks (important -- this means the child tasks
        // are cancelled when the parent is cancelled)
        async let distributeFrames: () = {
            for await sampleBuffer in frames {
                if let frame = sampleBuffer.imageBuffer {
                    framesToDisplayContinuation.yield(frame)
                    // Only send frames for analysis in continuous mode
                    if await selectedCameraType == .continuous {
                        framesToAnalyzeContinuation.yield(frame)
                    }
                }
            }

            // detach from the camera controller and feed to the video view
            await MainActor.run {
                self.framesToDisplay = nil
                self.camera.detatch()
            }

            framesToDisplayContinuation.finish()
            framesToAnalyzeContinuation.finish()
        }()

        // Only analyze frames if in continuous mode
        if selectedCameraType == .continuous {
            async let analyze: () = analyzeVideoFrames(framesToAnalyze)
            await distributeFrames
            await analyze
        } else {
            await distributeFrames
        }
    }

    /// Perform FastVLM inference on a single frame.
    /// - Parameter frame: The frame to analyze.
    func processSingleFrame(_ frame: CVImageBuffer) {
        Task {
            // 如果启用了图像相似度检测且不是仅使用文本相似度模式
            if model.similarityDetectionMode != .textOnly {
                // 检测图像相似度
                let similarityResult = await ImageSimilarityDetector.shared.detectSimilarity(for: frame)

                // 根据检测模式和结果决定是否处理新帧
                if (model.similarityDetectionMode == .imageOnly || model.similarityDetectionMode == .combined) &&
                   !similarityResult.shouldProcessNewFrame && !similarityResult.isFirstFrame {
                    // 如果图像相似度高且不是首帧，不处理
                    return
                }
            }

            // Reset Response UI (show spinner)
            await MainActor.run {
                model.output = ""
            }

            // Construct request to model
            let userInput = UserInput(
                prompt: .text("\(prompt) \(promptSuffix)"),
                images: [.ciImage(CIImage(cvPixelBuffer: frame))]
            )

            // Post request to FastVLM
            await model.generate(userInput)
        }
    }
}

#Preview {
    ContentView()
}
