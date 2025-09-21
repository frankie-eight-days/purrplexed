//
//  ImageUtils.swift
//  Purrplexed
//
//  Helpers to resize/compress images for network upload.
//

import UIKit

enum ImageUtils {
	/// Downscale and compress a UIImage to fit within maxDimension (longest side) and below targetBytes if possible.
	static func jpegDataFitting(_ image: UIImage, maxDimension: CGFloat = 1280, targetBytes: Int = 1_500_000, initialQuality: CGFloat = 0.8) -> Data? {
		let scaled = resize(image: image, maxDimension: maxDimension)
		var quality = initialQuality
		var data = scaled.jpegData(compressionQuality: quality)
		// Reduce quality iteratively if above target size
		var attempts = 0
		while let d = data, d.count > targetBytes, attempts < 5 {
			quality -= 0.15
			data = scaled.jpegData(compressionQuality: max(0.4, quality))
			attempts += 1
		}
		return data
	}
	
	private static func resize(image: UIImage, maxDimension: CGFloat) -> UIImage {
		let size = image.size
		let maxSide = max(size.width, size.height)
		guard maxSide > maxDimension else { return image }
		let scale = maxDimension / maxSide
		let newSize = CGSize(width: size.width * scale, height: size.height * scale)
		let format = UIGraphicsImageRendererFormat.default()
		format.scale = 1
		let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
		return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
	}
}
