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
            VStack(spacing: 20) {
                // 1. Live Preview of the Shareable Image
                if let composition {
                    ShareCanvasView(composition: composition, selectedOverlayID: $selectedOverlayID, onCanvasSizeChange: { size in
                        previewCanvasSize = size
                    })
                        .frame(maxWidth: 600) // Larger editor panel on wide screens
                        .aspectRatio(composition.canvasAspectRatio(), contentMode: .fit)
                        .cornerRadius(16)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                        .overlay(gestureLayer)
                } else {
                    Text("Image not available")
                }
                
                // 2. Caption Chips
                VStack(alignment: .leading) {
                    Text("Choose a Caption")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    WrapLayout(spacing: CGSize(width: 8, height: 8)) {
                        ForEach(captionOptions, id: \.self) { caption in
                        Button(action: {
                            updateCaption(to: caption)
                        }) {
                            Text(caption)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(currentCaptionText() == caption ? Color.accentColor : Color.secondary.opacity(0.2))
                                .foregroundColor(currentCaptionText() == caption ? .white : .primary)
                                .cornerRadius(20)
                                .lineLimit(1)
                        }
                        }
                    }
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                }

                // 3. Stickers / Emojis
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stickers")
                        .font(.headline)
                        .padding(.horizontal)

                    StickerPaletteView(emojis: ["😺","😼","😹","😻","😾","🐾","✨","💤"]) { emoji in
                        addEmojiSticker(emoji)
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Create & Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") { generateAndShare() }
                        .disabled(currentCaptionText().isEmpty || composition == nil)
                }
            }
            .onAppear {
                if composition == nil, let data = viewModel.thumbnailData, let image = UIImage(data: data) {
                    composition = ShareComposition.default(for: image, initialCaption: captionOptions.first ?? "")
                }
            }
            .sheet(isPresented: $isSharing, onDismiss: {
                sharedImage = nil
            }) {
                if let image = sharedImage {
                    ActivityView(activityItems: [image])
                }
            }
        }
    }

    private func generateAndShare() {
        guard let composition else {
            print("Error: Missing image data for sharing.")
            return
        }

        let targetSize = previewCanvasSize == .zero ? composition.targetSizePoints() : previewCanvasSize
        guard let renderedImage = ShareExportService.renderImage(from: composition, targetSize: targetSize, scale: UIScreen.main.scale) else {
            print("Error: Could not render share image.")
            return
        }

        sharedImage = renderedImage
        isSharing = true
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
}

// MARK: - Gesture Transform Overlay
private struct GestureTransformOverlay: View {
    @Binding var composition: ShareComposition
    let overlayIndex: Int

    @GestureState private var transientTranslation: CGSize = .zero
    @GestureState private var transientScale: CGFloat = 1.0
    @GestureState private var transientRotation: Angle = .zero

    var body: some View {
        GeometryReader { proxy in
            let aspect = composition.canvasAspectRatio()
            let canvasFrame = fittedRect(in: proxy.size, aspect: aspect)

            Color.clear
                .contentShape(Rectangle())
                .gesture(combinedGesture(canvasSize: canvasFrame.size))
                .frame(width: canvasFrame.width, height: canvasFrame.height)
                .position(x: canvasFrame.midX, y: canvasFrame.midY)
                .overlay(liveTransformedOverlay(in: canvasFrame))
        }
    }

    private func combinedGesture(canvasSize: CGSize) -> some Gesture {
        let drag = DragGesture()
            .updating($transientTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                var item = composition.overlays[overlayIndex]
                let dx = value.translation.width / canvasSize.width
                let dy = value.translation.height / canvasSize.height
                item.positionNormalized.x = min(max(0, item.positionNormalized.x + dx), 1)
                item.positionNormalized.y = min(max(0, item.positionNormalized.y + dy), 1)
                composition.overlays[overlayIndex] = item
            }

        let magnify = MagnificationGesture()
            .updating($transientScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                var item = composition.overlays[overlayIndex]
                item.scale = max(0.2, min(4.0, item.scale * value))
                composition.overlays[overlayIndex] = item
            }

        let rotate = RotationGesture()
            .updating($transientRotation) { value, state, _ in
                state = value
            }
            .onEnded { value in
                var item = composition.overlays[overlayIndex]
                item.rotationRadians += CGFloat(value.radians)
                composition.overlays[overlayIndex] = item
            }

        return drag.simultaneously(with: magnify).simultaneously(with: rotate)
    }

    // Live feedback: mirror the selected overlay with transient transforms applied
    @ViewBuilder private func liveTransformedOverlay(in canvasFrame: CGRect) -> some View {
        let canvasSize = canvasFrame.size
        if composition.overlays.indices.contains(overlayIndex) {
            var item = composition.overlays[overlayIndex]
            let livePoint = CGPoint(
                x: (item.positionNormalized.x * canvasSize.width) + transientTranslation.width,
                y: (item.positionNormalized.y * canvasSize.height) + transientTranslation.height
            )
            let liveScale = item.scale * transientScale
            let liveRotation = item.rotationRadians + CGFloat(transientRotation.radians)

            overlayView(for: item, canvasSize: canvasSize)
                .scaleEffect(liveScale)
                .rotationEffect(.radians(liveRotation))
                .position(livePoint)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder private func overlayView(for item: OverlayItem, canvasSize: CGSize) -> some View {
        switch item.kind {
        case .caption(let text):
            Text(text)
                .font(.system(size: min(ShareImageStyle.captionFontSize, canvasSize.width * 0.08), weight: ShareImageStyle.captionFontWeight, design: .rounded))
                .foregroundColor(.white)
                .padding(ShareImageStyle.captionPadding)
                .background(Color.black.opacity(ShareImageStyle.captionBackgroundOpacity))
                .cornerRadius(ShareImageStyle.captionCornerRadius)
                .frame(maxWidth: canvasSize.width * ShareImageStyle.captionMaxWidthRatio)
                .fixedSize(horizontal: false, vertical: true)
        case .stickerEmoji(let text):
            Text(text)
                .font(.system(size: max(32, canvasSize.width * 0.08)))
        case .watermark:
            EmptyView()
        }
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

