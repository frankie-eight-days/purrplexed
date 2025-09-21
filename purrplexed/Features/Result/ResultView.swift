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
					.buttonStyle(.borderedProminent)
					.accessibilityLabel("Share result")
				Button("Save") { services?.router.present(.paywall) }
					.font(DS.Typography.buttonFont())
					.buttonStyle(.bordered)
					.accessibilityLabel("Save result (Premium)")
			}
		}
		.padding()
		.sheet(isPresented: $isSharePresented) {
			ShareSheet(items: [URL(string: services?.env.apiBaseURL?.absoluteString ?? "https://example.com")!])
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
