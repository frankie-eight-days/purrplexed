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
	@State private var showPermissionDeniedAlert = false
	@State private var showShareCard = false
	
	var body: some View {
		ScrollView {
			VStack {
				photoPickerButton
				catFocusButtonView
				analyzeButton
				analysisResultsView
				Spacer()
			}
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
		.background(DS.Color.background)
	}
	
	private var photoPickerButton: some View {
		Button(action: { showChoice = true }) {
			ZStack {
				RoundedRectangle(cornerRadius: 16)
					.fill(Color.gray.opacity(0.2))
					.overlay(frameContent)
			}
		}
		.buttonStyle(.plain)
		.frame(maxWidth: .infinity)
		.frame(height: viewModel.optimalFrameHeight)
		.padding()
		.accessibilityLabel(Localized("add_photo"))
		.animation(.spring(response: 0.8, dampingFraction: 0.8), value: viewModel.optimalFrameHeight)
		.confirmationDialog(Localized("add_photo"), isPresented: $showChoice, titleVisibility: .visible) {
			Button(Localized("use_camera")) {
				handleCameraAction()
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
		.alert("Camera Permission Required", isPresented: $showPermissionDeniedAlert) {
			Button("Open Settings") {
				if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
					UIApplication.shared.open(settingsUrl)
				}
			}
			Button("Use Photo Library") { showLibrary = true }
			Button("Cancel", role: .cancel) {}
		} message: {
			Text("Purrplexed needs camera access to take photos. Please enable camera permissions in Settings → Privacy & Security → Camera → Purrplexed")
		}
		.sheet(isPresented: $showShareCard) {
			ShareCardView(viewModel: viewModel.createShareCardViewModel())
		}
	}
	
	private var catFocusButtonView: some View {
		// Cat detection indicator - shows when detecting
		Group {
			if viewModel.isDetectingCat {
				HStack {
					Spacer()
					HStack(spacing: 8) {
						ProgressView()
							.progressViewStyle(CircularProgressViewStyle(tint: DS.Color.accent))
							.scaleEffect(0.8)
						Text("Detecting cat...")
					}
					.font(.caption)
					.padding(.horizontal, 12)
					.padding(.vertical, 6)
					.background(.ultraThinMaterial)
					.clipShape(Capsule())
					.padding(.trailing)
					.padding(.top, -20)
					.transition(.opacity.combined(with: .scale))
				}
			}
		}
	}
	
	private var analyzeButton: some View {
		HStack(spacing: DS.Spacing.s) {
			// Analyze button - shrinks when share button appears
			Button(action: { viewModel.didTapAnalyze() }) {
				if viewModel.isAnalyzing {
					ProgressView()
						.progressViewStyle(CircularProgressViewStyle(tint: .white))
						.frame(maxWidth: .infinity)
						.padding(.vertical, 14)
				} else {
					Text(Localized("action_analyze"))
						.font(DS.Typography.buttonFont())
						.frame(maxWidth: .infinity)
						.padding(.vertical, 14)
				}
			}
			.buttonStyle(.borderedProminent)
			.disabled(viewModel.thumbnailData == nil || viewModel.isAnalyzing)
			
			// Share button - appears after analysis results are available
			if shouldShowShareButton {
				Button(action: { showShareCard = true }) {
					Image(systemName: "square.and.arrow.up")
						.font(DS.Typography.buttonFont())
						.frame(minWidth: 50)
						.padding(.vertical, 14)
				}
				.buttonStyle(.bordered)
				.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
			}
		}
		.padding(.horizontal)
		.animation(.spring(response: 0.6, dampingFraction: 0.8), value: shouldShowShareButton)
	}
	
	private var shouldShowShareButton: Bool {
		// Show share button when we have analysis results (any of them)
		return viewModel.emotionSummary != nil || 
			   viewModel.bodyLanguageAnalysis != nil || 
			   viewModel.contextualEmotion != nil || 
			   viewModel.ownerAdvice != nil ||
			   (viewModel.state.isReady && !viewModel.isAnalyzing)
	}
	
	private var analysisResultsView: some View {
		Group {
			if viewModel.emotionSummary != nil || viewModel.state.isReady {
				ParallelAnalysisResultsView(viewModel: viewModel)
					.padding(.horizontal)
					.transition(.opacity)
			}
		}
	}
	
	private func handleCameraAction() {
		if UIImagePickerController.isSourceTypeAvailable(.camera) {
			Task {
				let status = await viewModel.checkCameraPermission()
				switch status {
				case .granted:
					showCamera = true
				case .notDetermined:
					let newStatus = await viewModel.requestCameraPermission()
					if newStatus == .granted {
						showCamera = true
					} else if newStatus == .denied || newStatus == .restricted {
						showPermissionDeniedAlert = true
					}
				case .denied, .restricted:
					showPermissionDeniedAlert = true
				}
			}
		} else {
			showNoCameraAlert = true
		}
	}
	
	private var frameContent: some View {
		GeometryReader { geo in
			Group {
				if let data = viewModel.thumbnailData, let ui = UIImage(data: data) {
				AnimatedImageView(
					image: ui,
					catDetectionResult: viewModel.catDetectionResult,
					containerSize: geo.size
				)
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

// MARK: - Parallel Analysis Results View

struct ParallelAnalysisResultsView: View {
	@ObservedObject var viewModel: CaptureAnalysisViewModel
	@State private var expandedSections: Set<AnalysisSection> = []
	@State private var showEmotionSummary = false
	
	enum AnalysisSection: String, CaseIterable {
		case bodyLanguage = "Body Language"
		case contextualEmotion = "Contextual Analysis"
		case ownerAdvice = "Owner Advice"
		case catJokes = "Cat Jokes"
	}
	
	var body: some View {
		VStack(spacing: DS.Spacing.m) {
			// Emotion Summary - Always visible when available
			if showEmotionSummary, let emotionSummary = viewModel.emotionSummary {
				VStack(alignment: .leading, spacing: DS.Spacing.s) {
					HStack {
						Image(systemName: "heart.fill")
							.foregroundColor(DS.Color.accent)
						Text("Emotion Summary")
							.font(DS.Typography.titleFont())
							.fontWeight(.semibold)
						Spacer()
					}
					
					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Text("Emotion:")
								.fontWeight(.medium)
							HStack(spacing: 4) {
								Text(emotionSummary.emoji)
								Text(emotionSummary.emotion)
							}
							.foregroundColor(DS.Color.accent)
							Spacer()
							Text("(\(emotionSummary.intensity))")
								.font(.caption)
								.foregroundColor(.secondary)
						}
						
						Text(emotionSummary.description)
							.font(DS.Typography.bodyFont())
							.fixedSize(horizontal: false, vertical: true)
						
						// Warning message if present
						if let warningMessage = emotionSummary.warningMessage, !warningMessage.isEmpty {
							HStack(alignment: .top, spacing: 8) {
								Image(systemName: "exclamationmark.triangle.fill")
									.foregroundColor(.red)
								Text(warningMessage)
									.font(DS.Typography.bodyFont())
									.fontWeight(.medium)
									.foregroundColor(.red)
									.fixedSize(horizontal: false, vertical: true)
							}
							.padding(.top, 4)
						}
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding()
				.background(Color.blue.opacity(0.15))
				.clipShape(RoundedRectangle(cornerRadius: 12))
				.transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
			}
			
			// Expandable Tray Cards for other analyses
			ForEach(Array(AnalysisSection.allCases.enumerated()), id: \.element.rawValue) { index, section in
				if shouldShowSection(section) {
					AnalysisTrayCard(
						section: section,
						isExpanded: expandedSections.contains(section),
						onToggle: { toggleSection(section) },
						content: contentForSection(section)
					)
					.transition(.asymmetric(insertion: .move(edge: index.isMultiple(of: 2) ? .trailing : .leading).combined(with: .opacity), removal: .opacity))
				}
			}
			
			// Classic results fallback for backwards compatibility
			if case .ready(let result) = viewModel.state, viewModel.emotionSummary == nil {
				VStack(alignment: .leading, spacing: DS.Spacing.s) {
					Text(result.translatedText)
						.font(DS.Typography.bodyFont())
				}
				.frame(maxWidth: .infinity)
				.padding()
				.background(Color.gray.opacity(0.24))
				.clipShape(RoundedRectangle(cornerRadius: 12))
			}
		}
		.animation(.spring(response: 0.8), value: showEmotionSummary)
		.animation(.spring(response: 0.8), value: viewModel.bodyLanguageAnalysis?.overallMood)
		.animation(.spring(response: 0.8), value: viewModel.contextualEmotion?.emotionalMeaning)
		.animation(.spring(response: 0.8), value: viewModel.ownerAdvice?.immediateActions)
		.onAppear {
			showEmotionSummary = viewModel.emotionSummary != nil
		}
		.onChange(of: viewModel.emotionSummary) {
			showEmotionSummary = viewModel.emotionSummary != nil
		}
	}
	
	private func shouldShowSection(_ section: AnalysisSection) -> Bool {
		switch section {
		case .bodyLanguage:
			return viewModel.bodyLanguageAnalysis != nil
		case .contextualEmotion:
			return viewModel.contextualEmotion != nil
		case .ownerAdvice:
			return viewModel.ownerAdvice != nil
		case .catJokes:
			return viewModel.catJokes != nil
		}
	}
	
	private func toggleSection(_ section: AnalysisSection) {
		if expandedSections.contains(section) {
			expandedSections.remove(section)
		} else {
			expandedSections.insert(section)
		}
	}
	
	@ViewBuilder
	private func contentForSection(_ section: AnalysisSection) -> some View {
		switch section {
		case .bodyLanguage:
			if let analysis = viewModel.bodyLanguageAnalysis {
				BodyLanguageContentView(analysis: analysis)
			}
		case .contextualEmotion:
			if let analysis = viewModel.contextualEmotion {
				ContextualEmotionContentView(analysis: analysis)
			}
		case .ownerAdvice:
			if let analysis = viewModel.ownerAdvice {
				OwnerAdviceContentView(analysis: analysis)
			}
		case .catJokes:
			if let jokes = viewModel.catJokes {
				CatJokesContentView(jokes: jokes)
			}
		}
	}
}

// MARK: - Tray Card Component

struct AnalysisTrayCard<Content: View>: View {
	let section: ParallelAnalysisResultsView.AnalysisSection
	let isExpanded: Bool
	let onToggle: () -> Void
	let content: Content
	
	var body: some View {
		VStack(spacing: 0) {
			// Header
			HStack {
				Image(systemName: iconForSection(section))
					.foregroundColor(colorForSection(section))
				Text(section.rawValue)
					.font(DS.Typography.bodyFont())
					.fontWeight(.medium)
					.foregroundColor(.primary)
				Spacer()
				Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
					.font(.caption)
					.foregroundColor(.secondary)
			}
			.padding()
			.contentShape(Rectangle())
			.onTapGesture(perform: onToggle)
			
			// Content
			if isExpanded {
				content
					.padding(.horizontal)
					.padding(.bottom)
					.transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
			}
		}
		.background(backgroundColorForSection(section))
		.clipShape(RoundedRectangle(cornerRadius: 12))
		.animation(.easeInOut(duration: 0.3), value: isExpanded)
	}
	
	private func iconForSection(_ section: ParallelAnalysisResultsView.AnalysisSection) -> String {
		switch section {
		case .bodyLanguage: return "figure.walk"
		case .contextualEmotion: return "scope"
		case .ownerAdvice: return "lightbulb.fill"
		case .catJokes: return "face.smiling"
		}
	}
	
	private func colorForSection(_ section: ParallelAnalysisResultsView.AnalysisSection) -> Color {
		switch section {
		case .bodyLanguage: return .green
		case .contextualEmotion: return .orange
		case .ownerAdvice: return .purple
		case .catJokes: return .yellow
		}
	}
	
	private func backgroundColorForSection(_ section: ParallelAnalysisResultsView.AnalysisSection) -> Color {
		switch section {
		case .bodyLanguage: return Color.green.opacity(0.15)
		case .contextualEmotion: return Color.orange.opacity(0.15)
		case .ownerAdvice: return Color.purple.opacity(0.15)
		case .catJokes: return Color.yellow.opacity(0.15)
		}
	}
}

// MARK: - Content Views for Each Analysis Type

struct BodyLanguageContentView: View {
	let analysis: BodyLanguageAnalysis
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			AnalysisDetailRow(label: "Posture", value: analysis.posture)
			AnalysisDetailRow(label: "Ears", value: analysis.ears)
			AnalysisDetailRow(label: "Tail", value: analysis.tail)
			AnalysisDetailRow(label: "Eyes", value: analysis.eyes)
			AnalysisDetailRow(label: "Whiskers", value: analysis.whiskers)
			
			Divider()
				.padding(.vertical, 4)
			
			VStack(alignment: .leading, spacing: 4) {
				Text("Overall Mood")
					.font(.caption)
					.fontWeight(.medium)
					.foregroundColor(.secondary)
				Text(analysis.overallMood)
					.font(DS.Typography.bodyFont())
					.fontWeight(.medium)
					.foregroundColor(.green)
			}
		}
	}
}

struct ContextualEmotionContentView: View {
	let analysis: ContextualEmotion
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			BulletPointSection(label: "Context Clues", bullets: analysis.contextClues, bulletColor: .primary)
			BulletPointSection(label: "Environmental Factors", bullets: analysis.environmentalFactors, bulletColor: .primary)
			
			Divider()
				.padding(.vertical, 4)
			
			BulletPointSection(
				label: "Emotional Meaning", 
				bullets: analysis.emotionalMeaning, 
				bulletColor: .orange
			)
		}
	}
}

struct OwnerAdviceContentView: View {
	let analysis: OwnerAdvice
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			BulletPointSection(label: "Immediate Actions", bullets: analysis.immediateActionsBulletPoints)
			BulletPointSection(label: "Long-term Suggestions", bullets: analysis.longTermSuggestionsBulletPoints)
			
			// Only show warning signs if they exist and are not empty
			if !analysis.warningSignsBulletPoints.isEmpty {
				Divider()
					.padding(.vertical, 4)
				
				BulletPointSection(
					label: "Warning Signs", 
					bullets: analysis.warningSignsBulletPoints, 
					bulletColor: .red
				)
			}
		}
	}
}

struct CatJokesContentView: View {
	let jokes: CatJokes
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			ForEach(Array(jokes.jokes.enumerated()), id: \.offset) { index, joke in
				HStack(alignment: .top, spacing: 8) {
					Text("😸")
						.font(DS.Typography.bodyFont())
						.frame(width: 16, alignment: .leading)
					
					Text(joke)
						.font(DS.Typography.bodyFont())
						.fixedSize(horizontal: false, vertical: true)
				}
			}
		}
	}
}

struct BulletPointSection: View {
	let label: String
	let bullets: [String]
	let bulletColor: Color
	
	init(label: String, bullets: [String], bulletColor: Color = .primary) {
		self.label = label
		self.bullets = bullets
		self.bulletColor = bulletColor
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text(label)
				.font(.caption)
				.fontWeight(.medium)
				.foregroundColor(.secondary)
			
			ForEach(Array(bullets.enumerated()), id: \.offset) { index, bullet in
				HStack(alignment: .top, spacing: 6) {
					Text("•")
						.font(DS.Typography.bodyFont())
						.foregroundColor(bulletColor)
						.frame(width: 12, alignment: .leading)
					
					Text(bullet)
						.font(DS.Typography.bodyFont())
						.foregroundColor(bulletColor)
						.fixedSize(horizontal: false, vertical: true)
				}
			}
		}
	}
}

struct AnalysisDetailRow: View {
	let label: String
	let value: String
	
	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			Text(label)
				.font(.caption)
				.fontWeight(.medium)
				.foregroundColor(.secondary)
			Text(value)
				.font(DS.Typography.bodyFont())
				.fixedSize(horizontal: false, vertical: true)
		}
	}
}

// MARK: - Animated Image View for Cat Focus

struct AnimatedImageView: View {
	let image: UIImage
	let catDetectionResult: CatDetectionResult?
	let containerSize: CGSize
	
	@State private var imageOffset: CGSize = .zero
	@State private var imageScale: CGFloat = 1.0
	
	var body: some View {
		Image(uiImage: displayImage)
			.resizable()
			.scaledToFill()
			.scaleEffect(imageScale)
			.offset(imageOffset)
			.frame(width: containerSize.width, height: containerSize.height)
			.clipped()
			.onAppear {
				updateImageTransform(animated: false)
			}
			.onChange(of: catDetectionResult) {
				updateImageTransform(animated: true)
			}
	}
	
	private var displayImage: UIImage {
		// For smooth scaling, we use the original image and transform the view
		// rather than cropping the actual image
		return image
	}
	
	private func updateImageTransform(animated: Bool) {
		guard let catResult = catDetectionResult else {
			// No cat detected - return to original view
			let animation: Animation? = animated ? .spring() : nil
			withAnimation(animation) {
				imageOffset = .zero
				imageScale = 1.0
			}
			return
		}
		
		// Cat detected - automatically focus on it
		let transform = calculateCatFocusTransform(
			catBoundingBox: catResult.boundingBox,
			imageSize: catResult.imageSize,
			containerSize: containerSize
		)
		
		let animation: Animation? = animated ? .spring() : nil
		withAnimation(animation) {
			imageOffset = transform.offset
			imageScale = transform.scale
		}
	}
	
	private func calculateCatFocusTransform(
		catBoundingBox: CGRect,
		imageSize: CGSize,
		containerSize: CGSize
	) -> (offset: CGSize, scale: CGFloat) {
		// Calculate the scale factor to fit the image in the container
		let containerAspectRatio = containerSize.width / containerSize.height
		let imageAspectRatio = imageSize.width / imageSize.height
		
		let baseScale: CGFloat
		if imageAspectRatio > containerAspectRatio {
			// Image is wider, fit to height
			baseScale = containerSize.height / imageSize.height
		} else {
			// Image is taller, fit to width
			baseScale = containerSize.width / imageSize.width
		}
		
		// Add padding around the cat (20% of cat size)
		let paddingRatio: CGFloat = 0.3
		let paddingX = catBoundingBox.width * paddingRatio
		let paddingY = catBoundingBox.height * paddingRatio
		
		let expandedCatBox = catBoundingBox.insetBy(dx: -paddingX, dy: -paddingY)
		
		// Calculate the scale needed to make the cat area fit nicely in the container
		let catScaleX = containerSize.width / (expandedCatBox.width * baseScale)
		let catScaleY = containerSize.height / (expandedCatBox.height * baseScale)
		let catFocusScale = min(catScaleX, catScaleY, 2.5) // Cap at 2.5x zoom
		
		// Total scale combining base scaling and cat focus scaling
		let totalScale = baseScale * catFocusScale
		
		// Calculate center of the cat in image coordinates
		let catCenterX = catBoundingBox.midX
		let catCenterY = catBoundingBox.midY
		
		// Convert to view coordinates
		let scaledImageWidth = imageSize.width * totalScale
		let scaledImageHeight = imageSize.height * totalScale
		
		// Calculate where the cat center would be in the scaled image
		let catCenterInScaledImage = CGPoint(
			x: catCenterX * totalScale,
			y: catCenterY * totalScale
		)
		
		// Current center of the scaled image (before offset)
		let currentImageCenterX = scaledImageWidth / 2
		let currentImageCenterY = scaledImageHeight / 2
		
		// Calculate the offset from image center to cat center
		let catOffsetFromImageCenter = CGSize(
			width: catCenterInScaledImage.x - currentImageCenterX,
			height: catCenterInScaledImage.y - currentImageCenterY
		)
		
		// The offset we need is negative of the cat's offset from image center
		let finalOffset = CGSize(
			width: -catOffsetFromImageCenter.width,
			height: -catOffsetFromImageCenter.height
		)
		
		return (offset: finalOffset, scale: catFocusScale)
	}
}

private func Localized(_ key: String) -> String { NSLocalizedString(key, comment: "") }

#Preview("CaptureAnalysis - Minimal") {
	let vm = CaptureAnalysisViewModel(
		media: MockMediaService(),
		analysis: MockAnalysisService(),
		parallelAnalysis: MockParallelAnalysisService(),
		share: MockShareService(),
		analytics: MockAnalyticsService(),
		permissions: MockPermissionsService(),
		offlineQueue: InMemoryOfflineQueue(),
		captionService: MockCaptionGenerationService()
	)
	return CaptureAnalysisView(viewModel: vm)
}
