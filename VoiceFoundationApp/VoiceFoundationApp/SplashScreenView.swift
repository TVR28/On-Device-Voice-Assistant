import SwiftUI
import Foundation

struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var backgroundOpacity: Double = 1.0
    @Binding var isActive: Bool
    
    var body: some View {
        ZStack {
            // Pure black background
            Color.black
                .ignoresSafeArea()
            
            // Just the logo - clean and minimal
            Image("SplashLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
        }
        .opacity(backgroundOpacity)
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Logo entrance animation - smooth scale and fade in
        withAnimation(.easeOut(duration: 0.6)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // Exit animation after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                backgroundOpacity = 0.0
            }
            
            // Switch to main app after fade out completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isActive = false
            }
        }
    }
    

}



#Preview {
    SplashScreenView(isActive: .constant(true))
} 
