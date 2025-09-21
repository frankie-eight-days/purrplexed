//
//  PaywallView.swift
//  Purrplexed
//
//  Simple paywall placeholder.
//

import SwiftUI

struct PaywallView: View {
	var onClose: () -> Void
	var body: some View {
		NavigationView {
			VStack(spacing: DS.Spacing.l) {
				Image(systemName: "star.circle.fill").font(.system(size: 72)).foregroundStyle(.yellow)
				Text("Save is a Premium feature")
					.font(DS.Typography.titleFont())
				Text("Upgrade to unlock saving results.")
					.font(DS.Typography.bodyFont())
				Button("Close") { onClose() }
					.buttonStyle(.borderedProminent)
			}
			.padding()
			.navigationTitle("Premium")
		}
	}
}

#Preview { PaywallView(onClose: {}) }
