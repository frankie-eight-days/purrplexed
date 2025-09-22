//
//  OnboardingViewModel.swift
//  Purrplexed
//
//  ViewModel for onboarding flow with clean state management.
//

import Foundation
import SwiftUI
import AuthenticationServices

enum OnboardingStep: CaseIterable {
    case splash
    case auth
    case howItWorks
    case bestTips
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: - Published State
    @Published private(set) var currentStep: OnboardingStep = .splash
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    // Splash screen state
    @Published private(set) var splashAnimating = false
    @Published private(set) var showNextButton = false
    
    // Auth state
    @Published private(set) var isSigningIn = false
    @Published private(set) var authenticationComplete = false
    
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
                currentStep = .auth
            }
        case .auth:
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
    
    func handleSignInWithApple(_ result: Result<ASAuthorization, Error>) {
        guard !isSigningIn else { return }
        
        isSigningIn = true
        errorMessage = nil
        
        switch result {
        case .success(let authorization):
            handleSuccessfulAuthorization(authorization)
        case .failure(let error):
            handleAuthenticationError(error)
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
    
    private func handleSuccessfulAuthorization(_ authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            handleAuthenticationError(OnboardingError.invalidCredential)
            return
        }
        
        // In a real app, you'd validate with your backend and store user session
        services.analyticsService.track(event: "user_signed_in", properties: [
            "method": "apple_id",
            "user_id": appleIDCredential.user
        ])
        
        // Simulate a brief delay for UX
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            authenticationComplete = true
            isSigningIn = false
            moveToNextStep()
        }
    }
    
    private func handleAuthenticationError(_ error: Error) {
        isSigningIn = false
        
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                // User cancelled - don't show error
                return
            case .failed:
                errorMessage = "Authentication failed. Please try again."
            case .invalidResponse:
                errorMessage = "Invalid response from Apple. Please try again."
            case .notHandled:
                errorMessage = "Authentication not handled. Please try again."
            case .notInteractive:
                errorMessage = "Authentication requires user interaction. Please try again."
            case .unknown:
                errorMessage = "An unknown authentication error occurred."
            case .matchedExcludedCredential:
                errorMessage = "This credential was excluded. Please try a different method."
            @unknown default:
                errorMessage = "An unexpected error occurred during authentication."
            }
        } else {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        
        // Auto-dismiss error after 3 seconds
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            errorMessage = nil
        }
    }
}

// MARK: - Errors

enum OnboardingError: LocalizedError {
    case invalidCredential
    
    var errorDescription: String? {
        switch self {
        case .invalidCredential:
            return "Invalid authentication credential received."
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
