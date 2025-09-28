//
//  ShareController.swift
//  Purrplexed
//
//  UIKit share sheet wrapper for story exports.
//

import SwiftUI
import UIKit

final class ShareController: ObservableObject {
	static let shared = ShareController()
	private init() {}

	func presentShareSheet(with url: URL) {
		DispatchQueue.main.async {
			guard let scene = UIApplication.shared.connectedScenes
				.compactMap({ $0 as? UIWindowScene })
				.first,
				let root = scene.keyWindow?.rootViewController else {
					return
				}
			let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
			controller.completionWithItemsHandler = { _, _, _, _ in
				try? FileManager.default.removeItem(at: url)
			}
			root.present(controller, animated: true)
		}
	}
}

