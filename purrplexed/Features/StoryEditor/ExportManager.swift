//
//  ExportManager.swift
//  Purrplexed
//
//  Serial export actor for rendering story canvases.
//

import Foundation
import SwiftUI

actor ExportManager {
	enum ExportError: Error {
		case noBackground
		case renderFailed
		case writeFailed
	}

	private let rendererQueue = DispatchQueue(label: "com.purrplexed.story.export", qos: .userInitiated)

	func export(document: StoryDocument) async throws -> URL {
		try Task.checkCancellation()
		return try await withCheckedThrowingContinuation { continuation in
			rendererQueue.async {
				let renderView = StoryCanvasView(document: document)
				let renderer = ImageRenderer(content: renderView)
				renderer.scale = 1.0
				renderer.proposedSize = ProposedViewSize(width: document.canvasSize.width, height: document.canvasSize.height)
				guard let image = renderer.uiImage else {
					continuation.resume(throwing: ExportError.renderFailed)
					return
				}
				do {
					let url = try self.write(image: image)
					continuation.resume(returning: url)
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}

	private func write(image: UIImage) throws -> URL {
		let data = image.pngData()
		guard let png = data else { throw ExportError.renderFailed }
		let tempDir = FileManager.default.temporaryDirectory
		let fileURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("png")
		do {
			try png.write(to: fileURL, options: [.atomic])
			return fileURL
		} catch {
			throw ExportError.writeFailed
		}
	}
}

