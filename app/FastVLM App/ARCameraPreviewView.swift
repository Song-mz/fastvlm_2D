//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import SwiftUI
import UIKit
import AVFoundation
import Combine

/// AR摄像头预览视图，用于显示ARKit捕获的图像
struct ARCameraPreviewView: UIViewRepresentable {
    /// AR资源协调器
    @State private var coordinator = ARResourceCoordinator.shared

    /// 取消令牌
    @State private var cancellables = Set<AnyCancellable>()

    /// 创建UIView
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        // 创建预览层
        let previewLayer = AVSampleBufferDisplayLayer()
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        // 保存预览层到上下文
        context.coordinator.previewLayer = previewLayer

        // 设置自动调整大小
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        // 订阅图像更新
        coordinator.imageUpdatePublisher
            .receive(on: DispatchQueue.main)
            .sink { pixelBuffer in
                context.coordinator.displayPixelBuffer(pixelBuffer)
            }
            .store(in: &cancellables)

        return view
    }

    /// 更新UIView
    func updateUIView(_ uiView: UIView, context: Context) {
        // 确保预览层填满视图
        if let previewLayer = context.coordinator.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }

    /// 创建协调器
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// 协调器类
    class Coordinator {
        /// 预览层
        var previewLayer: AVSampleBufferDisplayLayer?

        /// 显示像素缓冲区
        func displayPixelBuffer(_ pixelBuffer: CVPixelBuffer) {
            // 创建CMSampleBuffer
            var sampleBuffer: CMSampleBuffer?
            var formatDescription: CMFormatDescription?

            // 创建格式描述
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                        imageBuffer: pixelBuffer,
                                                        formatDescriptionOut: &formatDescription)

            // 创建时间信息
            var timing = CMSampleTimingInfo(duration: CMTime.invalid,
                                           presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
                                           decodeTimeStamp: CMTime.invalid)

            // 创建样本缓冲区
            CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                   imageBuffer: pixelBuffer,
                                                   formatDescription: formatDescription!,
                                                   sampleTiming: &timing,
                                                   sampleBufferOut: &sampleBuffer)

            // 显示样本缓冲区
            if let sampleBuffer = sampleBuffer {
                // 在主线程更新UI
                DispatchQueue.main.async { [weak self] in
                    self?.previewLayer?.enqueue(sampleBuffer)

                    // 如果预览层没有在运行，启动它
                    if self?.previewLayer?.isReadyForMoreMediaData == true {
                        self?.previewLayer?.requestMediaDataWhenReady(on: .main) { [weak self] in
                            // 预览层已准备好显示更多数据
                            if let strongSelf = self, strongSelf.previewLayer?.isReadyForMoreMediaData == true {
                                // 已在enqueue方法中添加了样本缓冲区
                            }
                        }
                    }
                }
            }
        }
    }
}

/// 预览
#Preview {
    ARCameraPreviewView()
        .frame(height: 300)
        .onAppear {
            // 启动AR会话
            ARResourceCoordinator.shared.isLiDAREnabled = true
        }
}
