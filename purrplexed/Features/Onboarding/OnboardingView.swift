//
//  OnboardingView.swift
//  Purrplexed
//
//  Simplified onboarding flow with splash, how-it-works, and tips screens.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    
    init(services: ServiceContainer, onComplete: @escaping () -> Void) {
        self._viewModel = StateObject(wrappedValue: OnboardingViewModel(services: services, onComplete: onComplete))
    }
    
    var body: some View {
        ZStack {
            DS.Color.background
                .ignoresSafeArea()
            
            switch viewModel.currentStep {
            case .splash:
                SplashScreen(viewModel: viewModel)
            case .howItWorks:
                HowItWorksScreen(viewModel: viewModel)
            case .bestTips:
                BestTipsScreen(viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.startOnboarding()
        }
    }
}

// MARK: - Splash Screen

struct SplashScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()
            
            // Cat Icon Placeholder - you can replace with your app icon
            ZStack {
                Circle()
                    .fill(DS.Color.accent.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(viewModel.splashAnimating ? 1.0 : 0.8)
                    .opacity(viewModel.splashAnimating ? 1.0 : 0.7)
                
                Image(systemName: "cat.fill")
                    .font(.system(size: 50))
                    .foregroundColor(DS.Color.accent)
                    .scaleEffect(viewModel.splashAnimating ? 1.0 : 0.8)
            }
            
            VStack(spacing: DS.Spacing.m) {
                Text("Welcome to Purrplexed")
                    .font(DS.Typography.titleFont())
                    .multilineTextAlignment(.center)
                    .opacity(viewModel.splashAnimating ? 1.0 : 0.0)
                
                Text("The Vision Based AI Cat Translator")
                    .font(DS.Typography.bodyFont())
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .opacity(viewModel.splashAnimating ? 1.0 : 0.0)
            }
            
            Spacer()
            
            if viewModel.showNextButton {
                Button(action: viewModel.moveToNextStep) {
                    Text("Get Started")
                        .font(DS.Typography.buttonFont())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DS.Color.accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal, DS.Spacing.xl)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding()
    }
}


// MARK: - How It Works Screen

struct HowItWorksScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    private let steps = [
        ("camera.fill", "Take/Choose Photo", "Capture a photo of your cat or select from your gallery"),
        ("sparkles", "Press Analyze", "Our AI analyzes your cat's expressions and behavior"),
        ("eye.fill", "View Results", "Get insights into what your cat might be thinking"),
        ("square.and.arrow.up", "Share", "Share the fun results with friends and family")
    ]
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.m) {
                Text("How It Works")
                    .font(DS.Typography.titleFont())
                
                Text("Understanding your feline friend in 4 simple steps")
                    .font(DS.Typography.bodyFont())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: DS.Spacing.l) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HowItWorksStep(
                        number: index + 1,
                        iconName: step.0,
                        title: step.1,
                        description: step.2
                    )
                }
            }
            
            Spacer()
            
            Button(action: viewModel.moveToNextStep) {
                Text("Continue")
                    .font(DS.Typography.buttonFont())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DS.Color.accent)
                    .cornerRadius(12)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .disabled(viewModel.isLoading)
        }
        .padding()
    }
}

// MARK: - Best Tips Screen

struct BestTipsScreen: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    private let tips = [
        ("viewfinder", "Camera Detection", "Try to make sure your camera is detecting your cat in bounding boxes for best results"),
        ("eye", "Visible Features", "The more of your cat's features that are visible (eyes, ears, whiskers) the better"),
        ("light.max", "Good Lighting", "Well-lit photos help our AI better analyze your cat's expressions"),
        ("camera.macro", "Close-up Shots", "Get close enough to capture facial details, but not so close that features are cut off"),
        ("rectangle.on.rectangle", "Clear Background", "A simple background helps the AI focus on your cat's body language")
    ]
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.m) {
                Text("Best Tips for Success")
                    .font(DS.Typography.titleFont())
                
                Text("Follow these tips to get the most accurate translations")
                    .font(DS.Typography.bodyFont())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            ScrollView {
                VStack(spacing: DS.Spacing.l) {
                    ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                        BestTipCard(
                            iconName: tip.0,
                            title: tip.1,
                            description: tip.2
                        )
                    }
                }
                .padding(.horizontal, DS.Spacing.m)
            }
            
            Button(action: viewModel.completeOnboarding) {
                Text("Start Translating!")
                    .font(DS.Typography.buttonFont())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DS.Color.accent)
                    .cornerRadius(12)
            }
            .padding(.horizontal, DS.Spacing.xl)
            .disabled(viewModel.isLoading)
        }
        .padding()
    }
}

struct BestTipCard: View {
    let iconName: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            Image(systemName: iconName)
                .font(.system(size: 24))
                .foregroundColor(DS.Color.accent)
                .frame(width: 40, height: 40)
                .background(DS.Color.accent.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DS.Typography.buttonFont())
                
                Text(description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(DS.Color.pillBackground)
        .cornerRadius(12)
    }
}

struct HowItWorksStep: View {
    let number: Int
    let iconName: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.m) {
            ZStack {
                Circle()
                    .fill(DS.Color.accent)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(DS.Color.accent)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DS.Typography.buttonFont())
                
                Text(description)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding()
        .background(DS.Color.pillBackground)
        .cornerRadius(12)
    }
}

#Preview("Onboarding Flow") {
    let env = Env.load()
    let router = AppRouter()
    let usage = UsageMeterService(limit: env.freeDailyLimit)
    let container = ServiceContainer(env: env, router: router, usageMeter: usage)
    
    return OnboardingView(services: container, onComplete: {})
}
