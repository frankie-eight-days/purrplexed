//
//  ProcessingView.swift
//  Purrplexed
//
//  Simple processing screen presented modally.
//

import SwiftUI

struct ProcessingView: View {
	let jobId: String
	var body: some View {
		VStack(spacing: DS.Spacing.m) {
			ProgressView("Processing…")
				.progressViewStyle(.circular)
				.font(DS.Typography.bodyFont())
			Text("Job: \(jobId)")
				.font(.footnote)
				.foregroundStyle(.secondary)
		}
		.padding()
	}
}

#Preview { ProcessingView(jobId: "demo") }
