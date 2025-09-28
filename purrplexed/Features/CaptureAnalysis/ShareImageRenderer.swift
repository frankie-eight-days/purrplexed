import SwiftUI
import UIKit

// New export service that renders the same SwiftUI canvas used in preview
// for pixel-perfect parity between on-screen and exported image.
enum ShareImageRenderer {
    @MainActor
    static func render(content: some View, targetSize: CGSize, scale: CGFloat = UIScreen.main.scale, opaque: Bool = true) -> UIImage? {
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = .init(targetSize)
        renderer.scale = scale
        renderer.isOpaque = opaque
        return renderer.uiImage
    }
}
