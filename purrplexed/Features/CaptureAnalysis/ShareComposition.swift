import SwiftUI
import UIKit

enum CanvasMode: Hashable {
    case original
    case story9x16
    case square
}

struct ShareComposition: Hashable {
    var baseImage: UIImage
    var canvasMode: CanvasMode = .original
    var overlays: [OverlayItem] = []
}

enum OverlayKind: Hashable {
    case caption(text: String)
    case stickerEmoji(text: String)
    case watermark
}

struct OverlayItem: Identifiable, Hashable {
    let id: UUID
    var kind: OverlayKind
    var positionNormalized: CGPoint // 0...1, relative to canvas
    var scale: CGFloat
    var rotationRadians: CGFloat
    var zIndex: Int
    var isLocked: Bool
}

extension ShareComposition {
    static func `default`(for baseImage: UIImage, initialCaption: String) -> ShareComposition {
        var items: [OverlayItem] = []

        let captionItem = OverlayItem(
            id: UUID(),
            kind: .caption(text: initialCaption),
            positionNormalized: CGPoint(x: 0.5, y: 0.8),
            scale: 1.0,
            rotationRadians: 0,
            zIndex: 10,
            isLocked: false
        )
        items.append(captionItem)

        let watermarkItem = OverlayItem(
            id: UUID(),
            kind: .watermark,
            positionNormalized: CGPoint(x: 0.5, y: 0.95),
            scale: 1.0,
            rotationRadians: 0,
            zIndex: 0,
            isLocked: true
        )
        items.append(watermarkItem)

        return ShareComposition(baseImage: baseImage, canvasMode: .original, overlays: items)
    }
}

extension ShareComposition {
    func withBaseImage(_ image: UIImage) -> ShareComposition {
        var updated = self
        updated.baseImage = image
        return updated
    }
}

extension UIImage {
    var hashSignature: String {
        guard let data = self.jpegData(compressionQuality: 0.5) else {
            return ""
        }
        return String(data.hashValue)
    }
}

extension ShareComposition {
    func canvasAspectRatio() -> CGFloat {
        switch canvasMode {
        case .original:
            let size = baseImage.size
            guard size.height != 0 else { return 1 }
            return size.width / size.height
        case .story9x16:
            return ShareImageStyle.storyExportSize.width / ShareImageStyle.storyExportSize.height
        case .square:
            return 1.0
        }
    }

    func targetSizePoints() -> CGSize {
        switch canvasMode {
        case .original:
            return baseImage.size
        case .story9x16:
            return ShareImageStyle.storyExportSize
        case .square:
            return ShareImageStyle.squareExportSize
        }
    }

    func targetScale() -> CGFloat {
        switch canvasMode {
        case .original:
            return max(1, baseImage.scale)
        case .story9x16, .square:
            return 2.0
        }
    }
}

