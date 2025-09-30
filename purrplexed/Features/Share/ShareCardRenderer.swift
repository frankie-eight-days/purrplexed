import Foundation
import SwiftUI

@MainActor
struct ShareCardRenderer {
	static func renderPNG(for data: ShareCardData) -> URL? {
		let view = ShareCardView(data: data)
		let renderer = ImageRenderer(content: view)
		renderer.scale = 1.0
		renderer.proposedSize = ProposedViewSize(width: StoryTheme.canvasSize.width, height: StoryTheme.canvasSize.height)
		guard let image = renderer.uiImage else { return nil }
		let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
		guard let pngData = image.pngData() else { return nil }
		do {
			try pngData.write(to: tempURL, options: [.atomic])
			return tempURL
		} catch {
			return nil
		}
	}
}

