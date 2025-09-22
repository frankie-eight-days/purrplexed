//
//  OnboardingViewModel.swift
//  Purrplexed
//
//  ViewModel for onboarding flow with clean state management.
//

import Foundation
import SwiftUI

enum OnboardingStep: CaseIterable {
    case splash
    case howItWorks
    case bestTips
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: - Published State
    @Published private(set) var currentStep: OnboardingStep = .splash
    @Published private(set) var isLoading = false
    
    // Splash screen state
    @Published private(set) var splashAnimating = false
    @Published private(set) var showNextButton = false
    
    // MARK: - Dependencies
    private let services: ServiceContainer
    private let onComplete: () -> Void
    
    // MARK: - Private State
    private var animationTask: Task<Void, Never>?
    
    init(services: ServiceContainer, onComplete: @escaping () -> Void) {
        self.services = services
        self.onComplete = onComplete
    }
    
    deinit {
        animationTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    func startOnboarding() {
        guard currentStep == .splash else { return }
        startSplashAnimation()
    }
    
    func moveToNextStep() {
        switch currentStep {
        case .splash:
            withAnimation(.easeInOut(duration: 0.5)) {
                currentStep = .howItWorks
            }
        case .howItWorks:
            withAnimation(.easeInOut(duration: 0.5)) {
                currentStep = .bestTips
            }
        case .bestTips:
            completeOnboarding()
        }
    }
    
    func completeOnboarding() {
        // Save onboarding completion state
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        onComplete()
    }
    
    // MARK: - Private Methods
    
    private func startSplashAnimation() {
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            // Start entrance animation
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            guard !Task.isCancelled else { return }
            
            withAnimation(.easeInOut(duration: 1.0)) {
                splashAnimating = true
            }
            
            // Show continue button
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            guard !Task.isCancelled else { return }
            
            withAnimation(.easeInOut(duration: 0.5)) {
                showNextButton = true
            }
        }
    }
    
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasCompletedOnboarding") }
    }
}
