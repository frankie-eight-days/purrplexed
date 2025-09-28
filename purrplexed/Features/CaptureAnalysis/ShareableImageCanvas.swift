import SwiftUI

struct ShareableImageCanvas: View {
    let image: UIImage
    let caption: String
    
    @Binding var offset: CGSize
    @Binding var angle: Angle
    @Binding var scale: CGFloat

    @GestureState private var transientOffset: CGSize = .zero
    @GestureState private var transientAngle: Angle = .zero
    @GestureState private var transientScale: CGFloat = 1.0

    var body: some View {
        let dragGesture = DragGesture()
            .updating($transientOffset) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                offset.width += value.translation.width
                offset.height += value.translation.height
            }

        let rotationGesture = RotationGesture()
            .updating($transientAngle) { value, state, _ in
                state = value
            }
            .onEnded { value in
                angle += value
            }

        let magnificationGesture = MagnificationGesture()
            .updating($transientScale) { value, state, _ in
                state = value
            }
            .onEnded { value in
                scale *= value
            }

        let combinedGesture = dragGesture
            .simultaneously(with: magnificationGesture)
            .simultaneously(with: rotationGesture)

        GeometryReader { proxy in
            let canvasHeight = proxy.size.height

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay(alignment: .bottom) {
                    VStack(spacing: ShareImageStyle.captionSpacingFromWatermark) {
                        // Caption text bubble
                        Text(caption)
                            .font(.system(size: ShareImageStyle.captionFontSize, weight: ShareImageStyle.captionFontWeight, design: .rounded))
                            .foregroundColor(.white)
                            .padding(ShareImageStyle.captionPadding)
                            .background(Color.black.opacity(ShareImageStyle.captionBackgroundOpacity))
                            .cornerRadius(ShareImageStyle.captionCornerRadius)
                            .scaleEffect(scale * transientScale)
                            .rotationEffect(angle + transientAngle)
                            .offset(x: offset.width + transientOffset.width, y: offset.height + transientOffset.height)
                            .frame(maxWidth: proxy.size.width * ShareImageStyle.captionMaxWidthRatio)
                            .gesture(combinedGesture)

                        // Watermark
                        Text("Made with Purrplexed")
                            .font(.system(size: ShareImageStyle.watermarkFontSize, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(ShareImageStyle.watermarkPadding)
                            .background(Color.black.opacity(ShareImageStyle.watermarkBackgroundOpacity))
                            .cornerRadius(ShareImageStyle.watermarkCornerRadius)
                            .padding(.bottom, ShareImageStyle.watermarkBottomMargin)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, max(0, canvasHeight * 0.02))
                }
        }
    }
}
