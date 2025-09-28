import SwiftUI
import UIKit

enum ShareExportService {
    @MainActor
    static func renderImage(from composition: ShareComposition, targetSize: CGSize? = nil, scale: CGFloat? = nil) -> UIImage? {
        let resolvedTargetSize = targetSize ?? composition.targetSizePoints()
        let resolvedScale = scale ?? UIScreen.main.scale

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
}

