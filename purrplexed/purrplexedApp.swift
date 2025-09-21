//
//  purrplexedApp.swift
//  purrplexed
//
//  App entry hosting AppRootView with DI container.
//

import SwiftUI

@main
struct purrplexedApp: App {
    var body: some Scene {
        WindowGroup {
            let env = Env.load()
            let router = AppRouter()
            let usage = UsageMeterService(limit: env.freeDailyLimit)
            let image = MockImageProcessingService()
            let container = ServiceContainer(env: env, router: router, usageMeter: usage, imageService: image)
            AppRootView(services: container)
                .inject(container)
        }
    }
}
