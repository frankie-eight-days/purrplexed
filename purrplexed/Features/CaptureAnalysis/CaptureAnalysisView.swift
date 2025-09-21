//
//  CaptureAnalysisView.swift
//  Purrplexed
//
//  Minimal single-screen UI: white page with top grey square to add photo.
//

import SwiftUI
import UIKit

struct CaptureAnalysisView: View {
	@ObservedObject var viewModel: CaptureAnalysisViewModel
	@State private var showChoice = false
	@State private var showLibrary = false
	@State private var showCamera = false
	@State private var showNoCameraAlert = false
	
	var body: some View {
		VStack {
			Button(action: { showChoice = true }) {
				ZStack {
					RoundedRectangle(cornerRadius: 16)
						.fill(Color.gray.opacity(0.2))
						.overlay(frameContent)
				}
			}
			.buttonStyle(.plain)
			.frame(maxWidth: .infinity)
			.frame(height: 280)
			.padding()
			.accessibilityLabel(Localized("add_photo"))
			.confirmationDialog(Localized("add_photo"), isPresented: $showChoice, titleVisibility: .visible) {
				Button(Localized("use_camera")) {
					if UIImagePickerController.isSourceTypeAvailable(.camera) {
						showCamera = true
					} else {
						showNoCameraAlert = true
					}
				}
				Button(Localized("from_photo_library")) { showLibrary = true }
				Button(Localized("action_cancel"), role: .cancel) {}
			}
			.alert(Localized("camera_unavailable_title"), isPresented: $showNoCameraAlert) {
				Button(Localized("from_photo_library")) { showLibrary = true }
				Button(Localized("action_cancel"), role: .cancel) {}
			} message: {
				Text(Localized("camera_unavailable_message"))
			}

			Button(action: { viewModel.didTapAnalyze() }) {
				Text(Localized("action_analyze"))
					.font(DS.Typography.buttonFont())
					.frame(maxWidth: .infinity)
					.padding(.vertical, 14)
			}
			.buttonStyle(.borderedProminent)
			.padding(.horizontal)
			.disabled(viewModel.thumbnailData == nil)

			if case .ready(let result) = viewModel.state {
				VStack(alignment: .leading, spacing: DS.Spacing.s) {
					Text(result.translatedText)
						.font(DS.Typography.bodyFont())
				}
				.frame(maxWidth: .infinity)
				.padding()
				.background(Color.gray.opacity(0.08))
				.clipShape(RoundedRectangle(cornerRadius: 12))
				.padding(.horizontal)
				.transition(.opacity)
			}

			Spacer()
		}
		.background(DS.Color.background)
		.sheet(isPresented: $showLibrary) {
			PhotoLibraryPicker { image in
				if let image, let data = ImageUtils.jpegDataFitting(image) {
					viewModel.didPickPhoto(data)
				}
			}
		}
		.sheet(isPresented: $showCamera) {
			SystemCameraPicker { image in
				if let image, let data = ImageUtils.jpegDataFitting(image) {
					viewModel.didPickPhoto(data)
				}
			}
		}
	}
	
	private var frameContent: some View {
		GeometryReader { geo in
			Group {
				if let data = viewModel.thumbnailData, let ui = UIImage(data: data) {
					Image(uiImage: ui)
						.resizable()
						.scaledToFill()
						.frame(width: geo.size.width, height: geo.size.height)
						.clipped()
						.clipShape(RoundedRectangle(cornerRadius: 16))
				} else {
					Text(Localized("add_photo"))
						.font(DS.Typography.titleFont())
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity, maxHeight: .infinity)
				}
			}
		}
	}
}

private func Localized(_ key: String) -> String { NSLocalizedString(key, comment: "") }

#Preview("CaptureAnalysis - Minimal") {
	let vm = CaptureAnalysisViewModel(
		media: MockMediaService(),
		analysis: MockAnalysisService(),
		share: MockShareService(),
		analytics: MockAnalyticsService(),
		permissions: MockPermissionsService(),
		offlineQueue: InMemoryOfflineQueue()
	)
	return CaptureAnalysisView(viewModel: vm)
}
