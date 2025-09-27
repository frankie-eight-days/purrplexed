import SwiftUI
import UIKit

struct ShareComposerView: View {
	@ObservedObject var viewModel: CaptureAnalysisViewModel
	@Environment(\.dismiss) private var dismiss
	@Environment(\.services) private var services
	@State private var selectedCaptionIndex: Int = 0
	@State private var additionalNote: String = ""
	
	private var captions: [String] {
		var options: [String] = []
		if let summary = viewModel.emotionSummary {
			options.append("\(summary.emoji) \(summary.emotion.capitalized): \(summary.description)")
		}
		if let advice = viewModel.ownerAdvice {
			let bullets = advice.immediateActionsBulletPoints.prefix(2)
			if !bullets.isEmpty {
				options.append("Advice: \(bullets.joined(separator: " • "))")
			}
		}
		if options.isEmpty { options = ["Check out my cat analysis on Purrplexed!"] }
		return options
	}
	
	var body: some View {
		NavigationStack {
			Form {
				Section("Caption") {
					Picker("Choose a caption", selection: $selectedCaptionIndex) {
						ForEach(Array(captions.enumerated()), id: \.offset) { index, caption in
							Text(caption).tag(index)
						}
					}
				}
				Section("Add a note (optional)") {
					TextField("Add a fun note…", text: $additionalNote)
				}
			}
			.navigationTitle("Share")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") { dismiss() }
				}
				ToolbarItem(placement: .confirmationAction) {
					Button("Share") { share() }.disabled(captions.isEmpty)
				}
			}
		}
	}
	
	private func share() {
		guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
			  let root = windowScene.keyWindow?.rootViewController else { return }
		let base = captions[min(selectedCaptionIndex, max(0, captions.count - 1))]
		let final = additionalNote.isEmpty ? base : base + "\n" + additionalNote
		let activityVC = UIActivityViewController(activityItems: [final], applicationActivities: nil)
		root.present(activityVC, animated: true)
		// Dismiss after presenting the sheet to return to results when done
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
			dismiss()
		}
	}
}
