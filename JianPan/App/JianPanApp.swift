import SwiftUI

@main
struct JianPanApp: App {
    @StateObject private var marketStore = MarketStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(marketStore)
                .preferredColorScheme(.dark)
        }
    }
}

