import SwiftUI
import UIKit

struct ShareComposerView: View {
    @ObservedObject var viewModel: CaptureAnalysisViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.services) private var services
    
    // Unified composition model
    @State private var composition: ShareComposition?
    @State private var selectedOverlayID: UUID?
    
    // State for presenting the share sheet
    @State private var isSharing: Bool = false
    @State private var sharedImage: UIImage?
    @State private var previewCanvasSize: CGSize = .zero
    @State private var isGeneratingShare: Bool = false
    @State private var cachedShareImage: UIImage?
    @State private var cachedCompositionSignature: String?
    @State private var cachedTargetSize: CGSize = .zero
    @State private var cachedExportScale: CGFloat = 1.0
    @State private var preRenderTask: Task<Void, Never>?
    
    private var captionOptions: [String] {
        var options: [String] = []
        if let summary = viewModel.emotionSummary {
            options.append("\(summary.emoji) \(summary.description)")
        }
        if let bodyLanguage = viewModel.bodyLanguageAnalysis {
            options.append(bodyLanguage.overallMood)
        }
        if let contextual = viewModel.contextualEmotion?.emotionalMeaning.first {
            options.append(contextual)
        }
        if let advice = viewModel.ownerAdvice?.immediateActions.first {
            options.append("Pro-tip: \(advice)")
        }
        if let jokes = viewModel.catJokes?.jokes {
            options.append(contentsOf: jokes)
        }
        
        // Fallback option
        if options.isEmpty {
            options.append("My cat is a mystery wrapped in fur.")
        }
        
        return options
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let safeInsets = proxy.safeAreaInsets
                let basePadding: CGFloat = 24
                let horizontalPadding = max(basePadding, max(safeInsets.leading, safeInsets.trailing) + basePadding)
                let maxContentWidth = max(200, proxy.size.width - (horizontalPadding * 2))
                let maxCanvasWidth = min(maxContentWidth, proxy.size.width * 0.78, 300)
                let maxCanvasHeight = min(max(200, proxy.size.height * 0.5), 400)

                ScrollView {
                    LazyVStack(alignment: .center, spacing: 28, pinnedViews: []) {
                        adaptiveCanvas(availableWidth: maxContentWidth, maxCanvasWidth: maxCanvasWidth, maxCanvasHeight: maxCanvasHeight)

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Choose a Caption")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            WrapLayout(spacing: CGSize(width: 10, height: 10)) {
                                ForEach(captionOptions, id: \.self) { caption in
                                    Button(action: {
                                        updateCaption(to: caption)
                                    }) {
                                        Text(caption)
                                            .font(.callout)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(currentCaptionText() == caption ? Color.accentColor : Color.secondary.opacity(0.24))
                                            .foregroundColor(currentCaptionText() == caption ? .white : .primary)
                                            .clipShape(Capsule())
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Stickers")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            StickerPaletteView(emojis: ["😺","😼","😹","😻","😾","🐾","✨","💤"]) { emoji in
                                addEmojiSticker(emoji)
                            }
                        }

                        Spacer(minLength: 32)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.top, max(safeInsets.top + 12, 32))
                    .padding(.bottom, max(safeInsets.bottom + 12, 32))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Create & Share")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(ShareComposerToolbar(
                isShareDisabled: currentCaptionText().isEmpty || composition == nil,
                isGeneratingShare: isGeneratingShare,
                onCancel: { dismiss() },
                onShare: {
                    Task {
                        await generateAndShare()
                    }
                }
            ))
            .onAppear {
                loadCompositionIfNeeded()
            }
            .onChange(of: composition) { newValue in
                if let comp = newValue {
                    handleCompositionChanged(comp)
                }
            }
            .onChange(of: previewCanvasSize) { _ in
                if let comp = composition {
                    schedulePreRender(for: comp)
                }
            }
            .sheet(isPresented: $isSharing, onDismiss: {
                sharedImage = nil
            }) {
                if let image = sharedImage {
                    ActivityView(activityItems: [image])
                }
            }
            .onDisappear {
                preRenderTask?.cancel()
                preRenderTask = nil
            }
        }
    }

    @MainActor
    private func generateAndShare() async {
        guard !isGeneratingShare else { return }
        guard let composition else {
            print("Error: Missing image data for sharing.")
            return
        }

        let targetSize = resolvedTargetExportSize(for: composition)
        let exportScale = exportScale(for: composition)
        isGeneratingShare = true

        defer { isGeneratingShare = false }

        let signature = compositionSignature(for: composition)

        if let cachedShareImage,
           cachedCompositionSignature == signature,
           cachedTargetSize == targetSize,
           cachedExportScale == exportScale {
            sharedImage = cachedShareImage
            isSharing = true
            Haptics.success()
            return
        }

        await Task.yield()

        guard let renderedImage = ShareExportService.renderImage(from: composition, targetSize: targetSize, scale: exportScale) else {
            print("Error: Could not render share image.")
            return
        }

        cacheRenderedImage(renderedImage, signature: signature, targetSize: targetSize, scale: exportScale)

        sharedImage = renderedImage
        isSharing = true
        Haptics.success()
    }

    // MARK: - Gestures Layer
    @ViewBuilder private var gestureLayer: some View {
        if composition != nil,
           let selected = selectedOverlayID,
           let index = composition!.overlays.firstIndex(where: { $0.id == selected }),
           composition!.overlays.indices.contains(index) {
            GestureTransformOverlay(
                composition: Binding(get: { composition! }, set: { composition = $0 }),
                overlayIndex: index
            )
        }
    }

    private func updateCaption(to newText: String) {
        guard var comp = composition else { return }
        if let idx = comp.overlays.firstIndex(where: { if case .caption = $0.kind { return true } else { return false } }) {
            comp.overlays[idx].kind = .caption(text: newText)
            composition = comp
        }
    }

    private func currentCaptionText() -> String {
        if let comp = composition, let idx = comp.overlays.firstIndex(where: { if case .caption = $0.kind { return true } else { return false } }) {
            if case .caption(let text) = comp.overlays[idx].kind { return text }
        }
        return ""
    }

    private func addEmojiSticker(_ emoji: String) {
        guard var comp = composition else { return }
        let item = OverlayItem(
            id: UUID(),
            kind: .stickerEmoji(text: emoji),
            positionNormalized: CGPoint(x: 0.5, y: 0.5),
            scale: 1.0,
            rotationRadians: 0,
            zIndex: 5,
            isLocked: false
        )
        comp.overlays.append(item)
        composition = comp
        selectedOverlayID = item.id
    }

    @ViewBuilder
    private func adaptiveCanvas(availableWidth: CGFloat, maxCanvasWidth: CGFloat, maxCanvasHeight: CGFloat) -> some View {
        if let composition {
            let aspect = max(0.1, composition.canvasAspectRatio())
            let widthCandidateHeight = maxCanvasWidth / aspect
            let fitsWithinHeight = widthCandidateHeight <= maxCanvasHeight
            let finalWidth = fitsWithinHeight ? maxCanvasWidth : maxCanvasHeight * aspect
            let finalHeight = fitsWithinHeight ? widthCandidateHeight : maxCanvasHeight

            ShareCanvasView(
                composition: composition,
                selectedOverlayID: $selectedOverlayID,
                onCanvasSizeChange: { size in
                    previewCanvasSize = size
                    schedulePreRender(for: composition)
                }
            )
            .frame(width: finalWidth, height: finalHeight)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 12)
            .overlay(gestureLayer)
        } else {
            Text("Image not available")
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Pre-render helpers
extension ShareComposerView {
    @MainActor
    private func loadCompositionIfNeeded() {
        if composition == nil {
            if let originalData = viewModel.originalImageData,
               let image = UIImage(data: originalData) {
                let initialComposition = ShareComposition.default(for: image, initialCaption: captionOptions.first ?? "")
                composition = initialComposition
                if previewCanvasSize == .zero {
                    previewCanvasSize = initialComposition.targetSizePoints()
                }
                schedulePreRender(for: initialComposition)
                return
            }

            if let data = viewModel.thumbnailData,
               let image = UIImage(data: data) {
                let initialComposition = ShareComposition.default(for: image, initialCaption: captionOptions.first ?? "")
                composition = initialComposition
                if previewCanvasSize == .zero {
                    previewCanvasSize = initialComposition.targetSizePoints()
                }
                schedulePreRender(for: initialComposition)
            }
        } else if let comp = composition, previewCanvasSize == .zero {
            previewCanvasSize = comp.targetSizePoints()
            schedulePreRender(for: comp)
        }
    }

    @MainActor
    private func handleCompositionChanged(_ comp: ShareComposition) {
        if previewCanvasSize == .zero {
            previewCanvasSize = comp.targetSizePoints()
        }
        schedulePreRender(for: comp)
    }

    @MainActor
    private func schedulePreRender(for composition: ShareComposition) {
        preRenderTask?.cancel()
        let currentTargetSize = resolvedTargetExportSize(for: composition, preRender: true)
        let currentScale = exportScale(for: composition, preRender: true)
        let signature = compositionSignature(for: composition)

        if cachedCompositionSignature == signature,
           cachedTargetSize == currentTargetSize,
           cachedExportScale == currentScale,
           cachedShareImage != nil {
            return
        }

        preRenderTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }

            guard let rendered = ShareExportService.renderImage(from: composition, targetSize: currentTargetSize, scale: currentScale) else {
                return
            }

            cacheRenderedImage(rendered, signature: signature, targetSize: currentTargetSize, scale: currentScale)
        }
    }

    private func resolvedTargetExportSize(for composition: ShareComposition, preRender: Bool = false) -> CGSize {
        switch composition.canvasMode {
        case .story9x16:
            return ShareImageStyle.storyExportSize
        case .square:
            return ShareImageStyle.squareExportSize
        case .original:
            let baseSize = composition.baseImage.size
            guard baseSize.width > 0, baseSize.height > 0 else {
                return previewCanvasSize == .zero ? ShareImageStyle.storyExportSize : previewCanvasSize
            }
            let maxDimension = preRender ? ShareImageStyle.preRenderMaxDimension : ShareImageStyle.maxOriginalExportDimension
            guard maxDimension > 0 else { return baseSize }
            let longestSide = max(baseSize.width, baseSize.height)
            guard longestSide > 0 else { return baseSize }
            if longestSide <= maxDimension { return baseSize }
            let ratio = maxDimension / longestSide
            return CGSize(width: baseSize.width * ratio, height: baseSize.height * ratio)
        }
    }

    private func exportScale(for composition: ShareComposition, preRender: Bool = false) -> CGFloat {
        switch composition.canvasMode {
        case .story9x16, .square:
            return 1.0
        case .original:
            if preRender { return 1.0 }
            let baseScale = composition.baseImage.scale
            return max(1.0, min(baseScale, ShareImageStyle.maxRenderScale))
        }
    }

    @MainActor
    private func cacheRenderedImage(_ image: UIImage, signature: String, targetSize: CGSize, scale: CGFloat) {
        cachedShareImage = image
        cachedCompositionSignature = signature
        cachedTargetSize = targetSize
        cachedExportScale = scale
    }

    private func compositionSignature(for composition: ShareComposition) -> String {
        let overlaySignature = composition.overlays.map { item -> String in
            var components: [String] = []
            switch item.kind {
            case .caption(let text):
                components.append("caption:\(text)")
            case .stickerEmoji(let text):
                components.append("sticker:\(text)")
            case .watermark:
                components.append("watermark")
            }

            components.append("pos:\(item.positionNormalized.x),\(item.positionNormalized.y)")
            components.append("scale:\(item.scale)")
            components.append("rot:\(item.rotationRadians)")
            components.append("z:\(item.zIndex)")
            return components.joined(separator: "|")
        }.joined(separator: "||")

        return [
            composition.canvasMode.hashValue.description,
            composition.baseImage.hashSignature,
            overlaySignature
        ].joined(separator: "::")
    }
}

// MARK: - Toolbar Modifier
private struct ShareComposerToolbar: ViewModifier {
    let isShareDisabled: Bool
    let isGeneratingShare: Bool
    let onCancel: () -> Void
    let onShare: () -> Void

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: onCancel)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(action: onShare) {
            if isGeneratingShare {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Text("Preparing")
                }
            } else {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            }
            .disabled(isShareDisabled || isGeneratingShare)
        }
    }

    func body(content: Content) -> some View {
        content.toolbar { toolbarContent() }
    }
}

// MARK: - Gesture Transform Overlay
private struct GestureTransformOverlay: View {
    @Binding var composition: ShareComposition
    let overlayIndex: Int

    @State private var dragStartPosition: CGPoint?
    @State private var scaleStartValue: CGFloat?
    @State private var rotationStartValue: CGFloat?

    var body: some View {
        GeometryReader { proxy in
            let aspect = composition.canvasAspectRatio()
            let canvasFrame = fittedRect(in: proxy.size, aspect: aspect)

            Color.clear
                .contentShape(Rectangle())
                .frame(width: canvasFrame.width, height: canvasFrame.height)
                .position(x: canvasFrame.midX, y: canvasFrame.midY)
                .gesture(combinedGesture(canvasSize: canvasFrame.size))
        }
    }

    private func combinedGesture(canvasSize: CGSize) -> some Gesture {
        let drag = DragGesture()
            .onChanged { value in
                guard canvasSize.width > 0, canvasSize.height > 0 else { return }
                guard composition.overlays.indices.contains(overlayIndex) else { return }

                if dragStartPosition == nil {
                    dragStartPosition = composition.overlays[overlayIndex].positionNormalized
                }

                guard let start = dragStartPosition else { return }
                var item = composition.overlays[overlayIndex]

                let dx = value.translation.width / canvasSize.width
                let dy = value.translation.height / canvasSize.height
                item.positionNormalized.x = clamp(start.x + dx)
                item.positionNormalized.y = clamp(start.y + dy)
                composition.overlays[overlayIndex] = item
            }
            .onEnded { _ in
                dragStartPosition = nil
            }

        let magnify = MagnificationGesture()
            .onChanged { value in
                guard composition.overlays.indices.contains(overlayIndex) else { return }

                if scaleStartValue == nil {
                    scaleStartValue = composition.overlays[overlayIndex].scale
                }

                guard let start = scaleStartValue else { return }
                var item = composition.overlays[overlayIndex]
                item.scale = clampScale(start * value)
                composition.overlays[overlayIndex] = item
            }
            .onEnded { _ in
                scaleStartValue = nil
            }

        let rotate = RotationGesture()
            .onChanged { value in
                guard composition.overlays.indices.contains(overlayIndex) else { return }

                if rotationStartValue == nil {
                    rotationStartValue = composition.overlays[overlayIndex].rotationRadians
                }

                guard let start = rotationStartValue else { return }
                var item = composition.overlays[overlayIndex]
                item.rotationRadians = start + CGFloat(value.radians)
                composition.overlays[overlayIndex] = item
            }
            .onEnded { _ in
                rotationStartValue = nil
            }

        return drag.simultaneously(with: magnify).simultaneously(with: rotate)
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(0, value), 1)
    }

    private func clampScale(_ value: CGFloat) -> CGFloat {
        max(0.2, min(4.0, value))
    }

    private func fittedRect(in size: CGSize, aspect: CGFloat) -> CGRect {
        guard size.width > 0 && size.height > 0 && aspect > 0 else { return CGRect(origin: .zero, size: size) }
        let containerAspect = size.width / size.height
        if containerAspect > aspect {
            let height = size.height
            let width = height * aspect
            let x = (size.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: height)
        } else {
            let width = size.width
            let height = width / aspect
            let y = (size.height - height) / 2
            return CGRect(x: 0, y: y, width: width, height: height)
        }
    }
}

