//
//  CameraView.swift
//  Purrplexed
//
//  Camera feature view. No business logic, delegates to ViewModel.
//

import SwiftUI

struct CameraView: View {
	@ObservedObject var viewModel: CameraViewModel
	@Environment(\.services) private var services
	@State private var showChoice = false
	@State private var showCamera = false
	@State private var showLibrary = false

	var body: some View {
		ZStack(alignment: .topTrailing) {
			DS.Color.background.ignoresSafeArea()
			// Camera preview placeholder
			Rectangle()
				.fill(LinearGradient(colors: [.black.opacity(0.7), .gray.opacity(0.4)], startPoint: .top, endPoint: .bottom))
				.overlay(Text("Camera Preview").foregroundStyle(.white).font(DS.Typography.titleFont()))
				.accessibilityHidden(true)

			VStack {
				Spacer()
				shutter
				.padding(.bottom, DS.Spacing.xl)
			}

			UsageMeterPill(remaining: viewModel.remainingFree)
				.padding(DS.Spacing.m)
		}
		.onAppear { viewModel.onAppear() }
		.onDisappear { viewModel.onDisappear() }
		.sheet(isPresented: $showCamera) {
			SystemCameraPicker { image in
				if let image { viewModel.beginProcessing(with: image) }
			}
		}
		.sheet(isPresented: $showLibrary) {
			PhotoLibraryPicker { image in
				if let image { viewModel.beginProcessing(with: image) }
			}
		}
	}

	private var shutter: some View {
		Button(action: { showChoice = true }) {
			ZStack {
				Circle().fill(.white).frame(width: 84, height: 84)
				Circle().strokeBorder(DS.Color.accent, lineWidth: 4).frame(width: 92, height: 92)
			}
		}
		.buttonStyle(.plain)
		.frame(minWidth: 44, minHeight: 44)
		.accessibilityLabel("Shutter")
		.accessibilityHint("Choose or take a photo for processing")
		.disabled(!isIdle)
		.opacity(isIdle ? 1 : 0.5)
		.confirmationDialog("Select Photo Source", isPresented: $showChoice, titleVisibility: .visible) {
			Button("Take Photo") { showCamera = true }
			Button("Choose Photo") { showLibrary = true }
			Button("Cancel", role: .cancel) {}
		}
	}

	private var isIdle: Bool {
		if case .idle = viewModel.state { return true }
		return false
	}
}

#Preview {
	let env = Env.load()
	let container = ServiceContainer(env: env, router: AppRouter(), usageMeter: UsageMeterService(limit: env.freeDailyLimit), imageService: MockImageProcessingService())
	return CameraView(viewModel: CameraViewModel(services: container))
}
