import SwiftUI

// Legacy wrapper renamed to host the new unified canvas when needed
struct ShareableImageCanvas: View {
    let image: UIImage
    let caption: String

    @Binding var offset: CGSize
    @Binding var angle: Angle
    @Binding var scale: CGFloat

    var body: some View {
        // Bridge to new ShareCanvasView using a minimal composition with caption + watermark
        let composition = ShareComposition.default(for: image, initialCaption: caption)
        ShareCanvasView(composition: composition, selectedOverlayID: .constant(nil))
    }
}
