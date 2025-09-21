//
//  ImagePickers.swift
//  Purrplexed
//
//  SwiftUI wrappers for system camera and photo library pickers.
//

import SwiftUI
import UIKit
import PhotosUI

struct SystemCameraPicker: UIViewControllerRepresentable {
	final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
		let parent: SystemCameraPicker
		init(parent: SystemCameraPicker) { self.parent = parent }
		func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
			let image = info[.originalImage] as? UIImage
			parent.onImage(image)
			picker.dismiss(animated: true)
		}
		func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
			parent.onImage(nil)
			picker.dismiss(animated: true)
		}
	}
	
	var onImage: (UIImage?) -> Void
	
	func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
	
	func makeUIViewController(context: Context) -> UIImagePickerController {
		let picker = UIImagePickerController()
		picker.sourceType = .camera
		picker.allowsEditing = false
		picker.delegate = context.coordinator
		return picker
	}
	
	func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}

struct PhotoLibraryPicker: UIViewControllerRepresentable {
	final class Coordinator: NSObject, PHPickerViewControllerDelegate {
		let parent: PhotoLibraryPicker
		init(parent: PhotoLibraryPicker) { self.parent = parent }
		func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
			guard let provider = results.first?.itemProvider else {
				parent.onImage(nil)
				picker.dismiss(animated: true)
				return
			}
			if provider.canLoadObject(ofClass: UIImage.self) {
				provider.loadObject(ofClass: UIImage.self) { object, _ in
					DispatchQueue.main.async { [weak self] in
						self?.parent.onImage(object as? UIImage)
						picker.dismiss(animated: true)
					}
				}
			} else {
				DispatchQueue.main.async { [weak self] in
					self?.parent.onImage(nil)
					picker.dismiss(animated: true)
				}
			}
		}
	}
	
	var onImage: (UIImage?) -> Void
	
	func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
	
	func makeUIViewController(context: Context) -> PHPickerViewController {
		var config = PHPickerConfiguration(photoLibrary: .shared())
		config.filter = .images
		config.selectionLimit = 1
		let picker = PHPickerViewController(configuration: config)
		picker.delegate = context.coordinator
		return picker
	}
	
	func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
}
