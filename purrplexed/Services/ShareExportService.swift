import SwiftUI
import UIKit

enum ShareExportService {
    @MainActor
    static func renderImage(from composition: ShareComposition, targetSize: CGSize? = nil, scale: CGFloat? = nil) -> UIImage? {
        let resolvedTargetSize = clampTargetSize(from: composition, targetSize: targetSize)
        let resolvedScale = clampScale(proposed: scale ?? UIScreen.main.scale)

        let view = ShareCanvasView(
            composition: composition,
            selectedOverlayID: .constant(nil)
        )
        .dynamicTypeSize(.medium)
        .environment(\.colorScheme, .light)

        if #available(iOS 16.0, *) {
            return ShareImageRenderer.render(content: view, targetSize: resolvedTargetSize, scale: resolvedScale, opaque: true)
        } else {
            // Fallback: snapshot hosting controller at exact size
            let controller = UIHostingController(rootView: view.frame(width: resolvedTargetSize.width, height: resolvedTargetSize.height))
            let view = controller.view
            view?.bounds = CGRect(origin: .zero, size: resolvedTargetSize)
            view?.backgroundColor = .black
            let renderer = UIGraphicsImageRenderer(size: resolvedTargetSize)
            return renderer.image { _ in
                view?.drawHierarchy(in: CGRect(origin: .zero, size: resolvedTargetSize), afterScreenUpdates: true)
            }
        }
    }

    private static func clampTargetSize(from composition: ShareComposition, targetSize: CGSize?) -> CGSize {
        let desired = targetSize ?? composition.targetSizePoints()
        switch composition.canvasMode {
        case .story9x16:
            return ShareImageStyle.storyExportSize
        case .square:
            return ShareImageStyle.squareExportSize
        case .original:
            let maxDim = ShareImageStyle.maxOriginalExportDimension
            let width = min(desired.width, maxDim)
            let height = min(desired.height, maxDim)
            return CGSize(width: width, height: height)
        }
    }

    private static func clampScale(proposed: CGFloat) -> CGFloat {
        max(1.0, min(proposed, ShareImageStyle.maxRenderScale))
    }
}

