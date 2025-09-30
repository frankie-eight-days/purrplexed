import SwiftUI

struct ShareCardView: View {
	let data: ShareCardData
	
	var body: some View {
		ZStack {
			// Background gradient
			LinearGradient(
				colors: [
					Color(red: 0.95, green: 0.85, blue: 1.0),
					Color(red: 0.85, green: 0.75, blue: 0.95)
				],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			
			VStack(spacing: 24) {
				// Header with app branding
				VStack(spacing: 8) {
					Text("Purrplexed")
						.font(.system(size: 32, weight: .bold))
						.foregroundColor(.white)
					Text("Cat Mood Analysis")
						.font(.system(size: 16, weight: .medium))
						.foregroundColor(.white.opacity(0.9))
				}
				.padding(.top, 40)
				
				// Cat image
				if let imageData = data.catImageData,
				   let uiImage = UIImage(data: imageData) {
					Image(uiImage: uiImage)
						.resizable()
						.aspectRatio(contentMode: .fill)
						.frame(width: 300, height: 300)
						.clipShape(RoundedRectangle(cornerRadius: 24))
						.shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 8)
				}
				
				// Emotion badge
				HStack(spacing: 12) {
					Text(data.emoji)
						.font(.system(size: 48))
					Text(data.emotion)
						.font(.system(size: 28, weight: .bold))
						.foregroundColor(.white)
				}
				.padding(.horizontal, 32)
				.padding(.vertical, 16)
				.background(
					RoundedRectangle(cornerRadius: 20)
						.fill(Color.white.opacity(0.25))
						.background(
							RoundedRectangle(cornerRadius: 20)
								.fill(.ultraThinMaterial)
						)
				)
				
				Spacer()
				
				// Highlights section
				VStack(alignment: .leading, spacing: 16) {
					if !data.selectedContextHighlights.isEmpty {
						VStack(alignment: .leading, spacing: 8) {
							Text("🔍 Context")
								.font(.system(size: 16, weight: .semibold))
								.foregroundColor(.white.opacity(0.9))
							ForEach(data.selectedContextHighlights, id: \.self) { highlight in
								Text("• \(highlight)")
									.font(.system(size: 14))
									.foregroundColor(.white.opacity(0.85))
									.lineLimit(2)
							}
						}
					}
					
					if !data.selectedAdviceHighlights.isEmpty {
						VStack(alignment: .leading, spacing: 8) {
							Text("💡 Advice")
								.font(.system(size: 16, weight: .semibold))
								.foregroundColor(.white.opacity(0.9))
							ForEach(data.selectedAdviceHighlights, id: \.self) { highlight in
								Text("• \(highlight)")
									.font(.system(size: 14))
									.foregroundColor(.white.opacity(0.85))
									.lineLimit(2)
							}
						}
					}
				}
				.frame(maxWidth: .infinity, alignment: .leading)
				.padding(.horizontal, 32)
				.padding(.vertical, 24)
				.background(
					RoundedRectangle(cornerRadius: 20)
						.fill(Color.white.opacity(0.15))
				)
				.padding(.horizontal, 32)
				.padding(.bottom, 40)
			}
		}
		.frame(width: StoryTheme.canvasSize.width, height: StoryTheme.canvasSize.height)
	}
}