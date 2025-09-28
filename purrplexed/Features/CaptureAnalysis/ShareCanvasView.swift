import SwiftUI

struct ShareCanvasView: View {
    var composition: ShareComposition
    @Binding var selectedOverlayID: UUID?
    var onCanvasSizeChange: ((CGSize) -> Void)? = nil

    @State private var previewBaseImage: UIImage?

    var body: some View {
        GeometryReader { proxy in
            let aspect = composition.canvasAspectRatio()
            let canvasFrame = fittedRect(in: proxy.size, aspect: aspect)

            ZStack {
                // Background for non-original modes
                if composition.canvasMode != .original {
                    Rectangle().fill(Color.black)
                }

                // Canvas stage area
                ZStack {
                    // Base image fitted into canvas while preserving aspect ratio
                    Image(uiImage: previewBaseImage ?? composition.baseImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: canvasFrame.width, height: canvasFrame.height)
                        .clipped()

                    ForEach(sortedOverlays(composition.overlays)) { item in
                        overlayView(for: item, canvasSize: canvasFrame.size)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedOverlayID == item.id ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if !item.isLocked { selectedOverlayID = item.id }
                            }
                    }
                }
                .frame(width: canvasFrame.width, height: canvasFrame.height)
                .position(x: canvasFrame.midX, y: canvasFrame.midY)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                onCanvasSizeChange?(canvasFrame.size)
                downsampleBaseImageIfNeeded(to: canvasFrame.size)
            }
            .onChange(of: canvasFrame.size) { newSize in
                onCanvasSizeChange?(newSize)
                downsampleBaseImageIfNeeded(to: newSize)
            }
        }
        .dynamicTypeSize(.medium)
    }

    private func sortedOverlays(_ overlays: [OverlayItem]) -> [OverlayItem] {
        overlays.sorted { a, b in
            if a.zIndex == b.zIndex { return a.id.uuidString < b.id.uuidString }
            return a.zIndex < b.zIndex
        }
    }

    private func overlayView(for item: OverlayItem, canvasSize: CGSize) -> some View {
        let point = CGPoint(x: item.positionNormalized.x * canvasSize.width,
                            y: item.positionNormalized.y * canvasSize.height)

        return ZStack {
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
                Text("Made with Purrplexed")
                    .font(.system(size: ShareImageStyle.watermarkFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(ShareImageStyle.watermarkPadding)
                    .background(Color.black.opacity(ShareImageStyle.watermarkBackgroundOpacity))
                    .cornerRadius(ShareImageStyle.watermarkCornerRadius)
            }
        }
        .scaleEffect(item.scale)
        .rotationEffect(.radians(item.rotationRadians))
        .position(point)
    }

    private func downsampleBaseImageIfNeeded(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        // Only update if our cached image is missing or far off from target size to reduce churn
        let current = previewBaseImage?.size ?? .zero
        let deltaW = abs(current.width - size.width)
        let deltaH = abs(current.height - size.height)
        guard previewBaseImage == nil || deltaW > 16 || deltaH > 16 else { return }
        previewBaseImage = ImageUtils.resizeToFit(image: composition.baseImage, targetSize: size)
    }

    private func fittedRect(in size: CGSize, aspect: CGFloat) -> CGRect {
        guard size.width > 0 && size.height > 0 && aspect > 0 else { return CGRect(origin: .zero, size: size) }
        let containerAspect = size.width / size.height
        if containerAspect > aspect {
            // container is wider than content; fit by height
            let height = size.height
            let width = height * aspect
            let x = (size.width - width) / 2
            return CGRect(x: x, y: 0, width: width, height: height)
        } else {
            // container is taller; fit by width
            let width = size.width
            let height = width / aspect
            let y = (size.height - height) / 2
            return CGRect(x: 0, y: y, width: width, height: height)
        }
    }
}

