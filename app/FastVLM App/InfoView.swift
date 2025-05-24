//
// For licensing see accompanying LICENSE file.
// Copyright (C) 2025 Apple Inc. All Rights Reserved.
//

import Foundation
import SwiftUI

struct InfoView: View {
    @Environment(\.dismiss) var dismiss

    let paragraph1 = "**FastVLM¹** 是一个新型视觉语言模型系列，它使用 **FastViTHD**（一种分层混合视觉编码器）在低延迟下生成少量高质量的标记，从而显著缩短首字生成时间（TTFT）。"
    let paragraph2 = "这款应用展示了 **FastVLM** 模型的实际应用，允许用户自由定制提示词。FastVLM 使用 Qwen2-Instruct 大语言模型，没有额外的安全调整，因此修改提示词时请谨慎操作。"
    let footer = "1. **FastVLM: 视觉语言模型的高效视觉编码。** (CVPR 2025) Pavan Kumar Anasosalu Vasu, Fartash Faghri, Chun-Liang Li, Cem Koc, Nate True, Albert Antony, Gokul Santhanam, James Gabriel, Peter Grasch, Oncel Tuzel, Hadi Pouransari"

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20.0) {
                // I'm not going to lie, this doesn't make sense...
                // Wrapping `String`s with `.init()` turns them into `LocalizedStringKey`s
                // which gives us all of the fun Markdown formatting while retaining the
                // ability to use `String` variables. ¯\_(ツ)_/¯
                Text("\(.init(paragraph1))\n\n\(.init(paragraph2))\n\n")
                    .font(.body)

                Spacer()

                Text(.init(footer))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .textSelection(.enabled)
            .navigationTitle("信息")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .resizable()
                            .frame(width: 25, height: 25)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                #elseif os(macOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                #endif
            }
        }
    }
}

#Preview {
    InfoView()
}
