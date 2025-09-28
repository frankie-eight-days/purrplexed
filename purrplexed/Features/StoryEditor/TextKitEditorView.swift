//
//  TextKitEditorView.swift
//  Purrplexed
//
//  Rich text editor wrapper using TextKit 2 for story captions.
//

import SwiftUI
import UIKit

struct TextKitEditorView: UIViewRepresentable {
	final class Coordinator: NSObject, UITextViewDelegate {
		var parent: TextKitEditorView

		init(parent: TextKitEditorView) {
			self.parent = parent
		}

		func textViewDidChange(_ textView: UITextView) {
			parent.text = textView.text
		}

		func textViewDidBeginEditing(_ textView: UITextView) {
			parent.isFirstResponder = true
		}

		func textViewDidEndEditing(_ textView: UITextView) {
			parent.isFirstResponder = false
		}
	}

	@Binding var text: String
	var font: UIFont
	var textColor: UIColor
	@Binding var isFirstResponder: Bool

	func makeCoordinator() -> Coordinator {
		Coordinator(parent: self)
	}

	func makeUIView(context: Context) -> UITextView {
		let textView = UITextView()
		textView.delegate = context.coordinator
		textView.backgroundColor = .clear
		textView.textAlignment = .center
		textView.textContainerInset = .zero
		textView.textContainer.lineFragmentPadding = 0
		textView.isScrollEnabled = false
		textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
		textView.font = font
		textView.textColor = textColor
		textView.text = text
		textView.adjustsFontForContentSizeCategory = false
		return textView
	}

	func updateUIView(_ uiView: UITextView, context: Context) {
		if uiView.font != font {
			uiView.font = font
		}
		if uiView.textColor != textColor {
			uiView.textColor = textColor
		}
		if uiView.text != text {
			uiView.text = text
		}
		if isFirstResponder && !uiView.isFirstResponder {
			dispatchMainAsyncIfNeeded {
				uiView.becomeFirstResponder()
			}
		} else if !isFirstResponder && uiView.isFirstResponder {
			uiView.resignFirstResponder()
		}
	}

	private func dispatchMainAsyncIfNeeded(_ action: @escaping () -> Void) {
		if Thread.isMainThread {
			action()
		} else {
			DispatchQueue.main.async(execute: action)
		}
	}
}

