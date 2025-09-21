//
//  AudioView.swift
//  Purrplexed
//
//  Placeholder audio view.
//

import SwiftUI

struct AudioView: View {
	@ObservedObject var viewModel: AudioViewModel
	var body: some View {
		VStack(spacing: DS.Spacing.m) {
			Image(systemName: "waveform")
				.font(.system(size: 42))
				.accessibilityHidden(true)
			Text(viewModel.message)
				.font(DS.Typography.titleFont())
				.multilineTextAlignment(.center)
				.padding()
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(DS.Color.background)
		.accessibilityElement(children: .combine)
		.accessibilityLabel("Audio feature coming soon")
	}
}

#Preview {
	AudioView(viewModel: AudioViewModel())
}
