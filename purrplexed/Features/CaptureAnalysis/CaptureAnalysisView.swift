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
	@Environment(\.colorScheme) private var colorScheme
	@State private var showChoice = false
	@State private var showLibrary = false
	@State private var showCamera = false
	@State private var showNoCameraAlert = false
	@State private var showPermissionDeniedAlert = false
	@State private var randomCatEmoji = "🐈"
	
	private let catEmojis = ["🐈", "😹", "😻", "😼", "😽", "🙀", "😿", "😾", "🐅", "🐆"]

	var body: some View {
		ScrollView {
			VStack {
				photoPickerButton
				catFocusButtonView
				noCatDetectedBanner
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
		.onAppear(perform: setup)
	}
	
	private func setup() {
		randomCatEmoji = catEmojis.randomElement() ?? "🐈"
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
		.frame(height: viewModel.frameHeight)
		.padding()
		.accessibilityLabel(Localized("add_photo"))
		// No animation needed since frame height is fixed
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
	
	private var noCatDetectedBanner: some View {
		Group {
			if let message = viewModel.noCatDetectedMessage {
				VStack(alignment: .leading, spacing: 12) {
					bannerHeader(message: message)
					if viewModel.catDetectionBlocking {
						bannerActions
					}
				}
				.padding(.vertical, 14)
				.padding(.horizontal, 16)
				.background(Color.orange.opacity(0.15))
				.clipShape(RoundedRectangle(cornerRadius: 12))
				.padding(.horizontal)
				.transition(.move(edge: .top).combined(with: .opacity))
			}
		}
	}
	
	private func bannerHeader(message: String) -> some View {
		HStack(spacing: 12) {
			Image(systemName: "exclamationmark.triangle.fill")
				.foregroundColor(.orange)
			Text(message)
				.font(DS.Typography.captionFont())
				.foregroundColor(.primary)
		}
	}
	
	private var bannerActions: some View {
		HStack(spacing: 10) {
			bannerActionButton(title: "Choose Different Photo", style: .prominent) {
				showChoice = true
			}
			bannerActionButton(title: "Retry Detection", style: .neutral) {
				viewModel.retryCatDetection()
			}
			bannerActionButton(title: "Proceed Anyway", style: .quiet) {
				viewModel.overrideCatDetectionRequirement()
			}
		}
	}
	
	private enum BannerButtonStyle {
		case prominent
		case neutral
		case quiet
	}
	
	private func bannerActionButton(title: String, style: BannerButtonStyle, action: @escaping () -> Void) -> some View {
		let background: Color
		let foreground: Color
		let border: Color
		switch style {
		case .prominent:
			background = DS.Color.accent
			foreground = .white
			border = DS.Color.accent.opacity(0.01)
		case .neutral:
			let opacity = colorScheme == .dark ? 0.32 : 0.22
			background = Color.orange.opacity(opacity)
			foreground = Color.orange
			border = Color.orange.opacity(colorScheme == .dark ? 0.45 : 0.3)
		case .quiet:
			background = Color(.secondarySystemBackground)
			foreground = .primary
			border = Color(.separator).opacity(colorScheme == .dark ? 0.25 : 0.15)
		}
		
		return Button(action: action) {
			Text(title)
				.font(DS.Typography.captionFont())
				.fontWeight(.semibold)
				.lineLimit(1)
				.minimumScaleFactor(0.8)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 11)
				.padding(.horizontal, 10)
		}
		.buttonStyle(.plain)
		.background(background)
		.foregroundColor(foreground)
		.clipShape(Capsule())
		.overlay(
			Capsule()
				.stroke(border, lineWidth: 1)
		)
	}
	
	private var analyzeButton: some View {
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
		.disabled(viewModel.thumbnailData == nil || viewModel.isAnalyzing || viewModel.catDetectionBlocking)
		.padding(.horizontal)
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
					Text("Add \(randomCatEmoji) photo")
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
							.foregroundColor(colorForMoodType(emotionSummary.moodType))
							Spacer()
							Text("(\(emotionSummary.intensity))")
								.font(.caption)
								.foregroundColor(.secondary)
						}
						
						Text(emotionSummary.description)
							.font(DS.Typography.bodyFont())
							.fixedSize(horizontal: false, vertical: true)
						
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
				Text(analysis.overallMood.capitalized)
					.font(DS.Typography.bodyFont())
					.fontWeight(.medium)
					.foregroundColor(colorForMoodType(analysis.overallMood))
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
					.frame(width: 20, alignment: .leading)
				
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
	
	@State private var currentTransform: ImageTransform = ImageTransform()
	
	var body: some View {
		Image(uiImage: image)
			.resizable()
			.scaledToFill()  // Always fill the container
			.scaleEffect(currentTransform.scale)
			.offset(currentTransform.offset)
			.frame(width: containerSize.width, height: containerSize.height)
			.clipped()
			.onAppear {
				updateTransform(animated: false)
			}
			.onChange(of: catDetectionResult) {
				updateTransform(animated: true)
			}
	}
	
	private func updateTransform(animated: Bool) {
		let newTransform = calculateImageTransform()
		
		if animated {
			withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
				currentTransform = newTransform
			}
		} else {
			currentTransform = newTransform
		}
	}
	
	private func calculateImageTransform() -> ImageTransform {
		// When no cat is detected, scaledToFill already handles filling the container
		// So we just need scale = 1.0 and offset = .zero
		guard let catResult = catDetectionResult else {
			return ImageTransform(scale: 1.0, offset: .zero)
		}
		
		let boundingWidth = catResult.boundingBox.width
		let boundingHeight = catResult.boundingBox.height
		let imagePixelWidth = max(catResult.imageSize.width, 1)
		let imagePixelHeight = max(catResult.imageSize.height, 1)
		let widthRatio = boundingWidth / imagePixelWidth
		let heightRatio = boundingHeight / imagePixelHeight
		let boundingAspect = boundingWidth / max(boundingHeight, 1)
		let containerAspect = containerSize.width / max(containerSize.height, 1)
		
		// Skip zoom when detection already fills most of the image or aspect ratio is extreme
		if widthRatio > 0.85 && heightRatio > 0.6 {
			return ImageTransform(scale: 1.0, offset: .zero)
		}
		let aspectRatioDifference = boundingAspect / max(containerAspect, 0.01)
		if aspectRatioDifference < 0.45 || aspectRatioDifference > 1.8 {
			return ImageTransform(scale: 1.0, offset: .zero)
		}
		
		// Use the image's point size (not pixel size)
		let imageSize = image.size
		
		// Cat detected - calculate zoom to focus on cat with padding
		let paddingRatio: CGFloat = 0.3 // 30% padding as requested
		
		// Calculate how scaledToFill is already scaling the image
		let scaleX = containerSize.width / imageSize.width
		let scaleY = containerSize.height / imageSize.height
		let fillScale = max(scaleX, scaleY) // This is what scaledToFill does
		
		// Convert bounding box from pixel coordinates to point coordinates
		// The catResult.imageSize is in pixels, but we need points for UI
		let pixelToPointScale = image.scale
		let catBoxInPoints = CGRect(
			x: catResult.boundingBox.minX / pixelToPointScale,
			y: catResult.boundingBox.minY / pixelToPointScale,
			width: catResult.boundingBox.width / pixelToPointScale,
			height: catResult.boundingBox.height / pixelToPointScale
		)
		
		// Expand the bounding box by padding
		let paddingX = catBoxInPoints.width * paddingRatio
		let paddingY = catBoxInPoints.height * paddingRatio
		var targetBox = catBoxInPoints.insetBy(dx: -paddingX, dy: -paddingY)
		
		// Ensure the target box stays within image bounds (in points)
		targetBox = targetBox.intersection(CGRect(origin: .zero, size: imageSize))
		
		// Calculate how much of the container the cat box takes up after fillScale
		let catWidthInContainer = targetBox.width * fillScale
		let catHeightInContainer = targetBox.height * fillScale
		
		// Calculate additional zoom needed to make the cat fill the container
		let additionalScaleX = containerSize.width / catWidthInContainer
		let additionalScaleY = containerSize.height / catHeightInContainer
		let additionalScale = min(additionalScaleX, additionalScaleY)
		
		// Cap the zoom at a reasonable level
		let maxZoom: CGFloat = 1.8
		let clampedScale = min(additionalScale, maxZoom)
		
		if clampedScale <= 1.05 {
			return ImageTransform(scale: 1.0, offset: .zero)
		}
		
		// Calculate offset to center the cat in the frame
		// Since scaledToFill already centers the image, we need to calculate the offset
		// from the centered position
		
		// First, figure out where the image is positioned after scaledToFill
		let scaledImageWidth = imageSize.width * fillScale
		let scaledImageHeight = imageSize.height * fillScale
		
		// After additional scaling
		let finalImageWidth = scaledImageWidth * clampedScale
		let finalImageHeight = scaledImageHeight * clampedScale
		
		// Cat center in the final scaled image
		let catCenterInImage = CGPoint(
			x: targetBox.midX * fillScale * clampedScale,
			y: targetBox.midY * fillScale * clampedScale
		)
		
		// The image is centered by scaledToFill, so its center is at container center
		// We need to offset from there to bring the cat to the center
		let imageCenter = CGPoint(
			x: finalImageWidth / 2,
			y: finalImageHeight / 2
		)
		
		// Offset needed to center the cat
		var offset = CGSize(
			width: imageCenter.x - catCenterInImage.x,
			height: imageCenter.y - catCenterInImage.y
		)
		
		// Constrain offset to prevent showing blank areas
		let maxOffsetX = abs(finalImageWidth - containerSize.width) / 2
		let maxOffsetY = abs(finalImageHeight - containerSize.height) / 2
		
		offset.width = max(-maxOffsetX, min(maxOffsetX, offset.width))
		offset.height = max(-maxOffsetY, min(maxOffsetY, offset.height))
		
		return ImageTransform(scale: clampedScale, offset: offset)
	}
}

// Helper struct to encapsulate transform state
struct ImageTransform: Equatable {
	var scale: CGFloat = 1.0
	var offset: CGSize = .zero
}

private func Localized(_ key: String) -> String { NSLocalizedString(key, comment: "") }

private func colorForMoodType(_ mood: String) -> Color {
	switch mood.lowercased() {
	case "relaxed": return .blue
	case "content": return .green
	case "playful": return .orange
	case "alert": return .yellow
	case "cautious": return .orange
	case "stressed": return .red
	default: return DS.Color.accent
	}
}

#Preview("CaptureAnalysis - Minimal") {
	let vm = CaptureAnalysisViewModel(
		media: MockMediaService(),
		analysis: MockAnalysisService(),
		parallelAnalysis: MockParallelAnalysisService(),
		analytics: MockAnalyticsService(),
		permissions: MockPermissionsService(),
		usageMeter: UsageMeterService(limit: 3),
		subscriptionService: MockSubscriptionService()
	)
	CaptureAnalysisView(viewModel: vm)
}
