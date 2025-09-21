//
//  UsageMeterPill.swift
//  Purrplexed
//
//  Small pill showing remaining free count.
//

import SwiftUI

struct UsageMeterPill: View {
	let remaining: Int

	var body: some View {
		Text("\(remaining) free left today")
			.font(DS.Typography.bodyFont())
			.padding(.horizontal, DS.Spacing.m)
			.padding(.vertical, DS.Spacing.s)
			.background(DS.Color.pillBackground)
			.clipShape(Capsule())
			.accessibilityLabel("Usage remaining: \(remaining) free left today")
	}
}

#Preview {
	UsageMeterPill(remaining: 3)
		.padding()
}
