import SwiftUI

@main
struct VoiceFoundationApp: App {
    var body: some Scene {
        WindowGroup {
            SplashScreenRootView()
        }
    }
}

struct SplashScreenRootView: View {
    @State private var showSplash = true
    
    var body: some View {
        if showSplash {
            SplashScreenView(isActive: $showSplash)
        } else {
            ContentView()
        }
    }
}
