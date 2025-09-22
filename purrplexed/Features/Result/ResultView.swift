//
//  ResultView.swift
//  Purrplexed
//
//  Result screen with share (free) and save (premium gated).
//

import SwiftUI

struct ResultView: View {
	let jobId: String
	@Environment(\.services) private var services
	@State private var isSharePresented = false
	@State private var isPremium = false
	@State private var isSaving = false
	
	var body: some View {
		VStack(spacing: DS.Spacing.l) {
			Image(systemName: "photo")
				.resizable()
				.scaledToFit()
				.frame(height: 220)
				.accessibilityHidden(true)
			Text("Result ready")
				.font(DS.Typography.titleFont())

			HStack(spacing: DS.Spacing.m) {
				Button("Share") { isSharePresented = true }
					.font(DS.Typography.buttonFont())
					.buttonStyle(BorderedProminentButtonStyle())
					.accessibilityLabel("Share result")
				
				saveButton
			}
		}
		.padding()
		.task {
			isPremium = await services?.subscriptionService.isPremium ?? false
		}
		.sheet(isPresented: $isSharePresented) {
			ShareSheet(items: [URL(string: services?.env.apiBaseURL?.absoluteString ?? "https://example.com")!])
		}
	}
	
	private var saveButton: some View {
		Group {
			if isPremium {
				Button(saveButtonText) {
					saveResult()
				}
				.font(DS.Typography.buttonFont())
				.buttonStyle(.borderedProminent)
				.disabled(isSaving)
				.accessibilityLabel("Save result")
			} else {
				Button(saveButtonText) {
					services?.router.present(.paywall)
				}
				.font(DS.Typography.buttonFont())
				.buttonStyle(.bordered)
				.disabled(isSaving)
				.accessibilityLabel("Save result (Premium required)")
			}
		}
	}
	
	private var saveButtonText: String {
		if isSaving {
			return "Saving..."
		} else if isPremium {
			return "Save"
		} else {
			return "Save (Premium)"
		}
	}
	
	private func saveResult() {
		guard isPremium else { return }
		isSaving = true
		
		// Simulate save operation
		Task {
			try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
			await MainActor.run {
				isSaving = false
				// TODO: Implement actual save logic here
				// For now, just show a success state
			}
		}
	}
}

private struct ShareSheet: UIViewControllerRepresentable {
	let items: [Any]
	func makeUIViewController(context: Context) -> UIActivityViewController {
		UIActivityViewController(activityItems: items, applicationActivities: nil)
	}
	func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview { ResultView(jobId: "demo") }
