import Foundation
import SwiftUI

@MainActor
class UnifiedLLMManager: ObservableObject {
    @Published var outputText: String = ""
    @Published var isGenerating: Bool = false
    @Published var isLoaded: Bool = false
    @Published var error: String?
    
    // Callback for when response is complete
    var onResponseComplete: ((String) -> Void)?
    
    // Callback for streaming TTS - called as text is being generated
    var onStreamingText: ((String) -> Void)?
    
    private var mockLLM: MockLLMManager
    private var realLLM: StatefulLLMManager
    private var useMockLLM: Bool = false
    
    init() {
        self.mockLLM = MockLLMManager()
        self.realLLM = StatefulLLMManager()
        
        // Set up callbacks
        setupCallbacks()
    }
    
    private func setupCallbacks() {
        // Mock LLM callbacks
        mockLLM.onResponseComplete = { [weak self] response in
            self?.onResponseComplete?(response)
        }
        
        mockLLM.onStreamingText = { [weak self] text in
            self?.onStreamingText?(text)
        }
        
        // Real LLM callbacks
        realLLM.onResponseComplete = { [weak self] response in
            self?.onResponseComplete?(response)
        }
        
        realLLM.onStreamingText = { [weak self] text in
            self?.onStreamingText?(text)
        }
    }
    
    func updateMode(useMock: Bool) {
        print("🔄 UnifiedLLMManager: updateMode called with useMock = \(useMock)")
        self.useMockLLM = useMock
        updatePublishedProperties()
        print("🔄 UnifiedLLMManager: mode updated, useMockLLM = \(self.useMockLLM)")
    }
    
    private func updatePublishedProperties() {
        if useMockLLM {
            self.outputText = mockLLM.outputText
            self.isGenerating = mockLLM.isGenerating
            self.isLoaded = mockLLM.isLoaded
            self.error = mockLLM.error
        } else {
            self.outputText = realLLM.outputText
            self.isGenerating = realLLM.isGenerating
            self.isLoaded = realLLM.isLoaded
            self.error = realLLM.error
        }
    }
    
    func generateResponse(for prompt: String) {
        print("🎯 UnifiedLLMManager: generateResponse called, useMockLLM = \(useMockLLM)")
        
        // Clear current state
        outputText = ""
        error = nil
        
        if useMockLLM {
            print("🎭 Using MockLLMManager")
            mockLLM.generateResponse(for: prompt)
            
            // Monitor mock LLM state changes
            Task {
                while mockLLM.isGenerating {
                    await MainActor.run {
                        self.outputText = mockLLM.outputText
                        self.isGenerating = mockLLM.isGenerating
                        self.error = mockLLM.error
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
                
                // Final update
                await MainActor.run {
                    self.outputText = mockLLM.outputText
                    self.isGenerating = mockLLM.isGenerating
                    self.error = mockLLM.error
                }
            }
        } else {
            print("🤖 Using StatefulLLMManager")
            // Check if real LLM is loaded
            if !realLLM.isLoaded {
                print("❌ Real LLM not loaded yet, isLoaded = \(realLLM.isLoaded), error = \(realLLM.error ?? "none")")
                error = "Real LLM is still loading. Please wait or switch to Demo mode in Settings."
                return
            }
            
            print("✅ Real LLM is loaded, generating response...")
            realLLM.generateResponse(for: prompt)
            
            // Monitor real LLM state changes
            Task {
                while realLLM.isGenerating {
                    await MainActor.run {
                        self.outputText = realLLM.outputText
                        self.isGenerating = realLLM.isGenerating
                        self.error = realLLM.error
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
                
                // Final update
                await MainActor.run {
                    self.outputText = realLLM.outputText
                    self.isGenerating = realLLM.isGenerating
                    self.error = realLLM.error
                }
            }
        }
    }
    
    func resetConversation() {
        mockLLM.resetConversation()
        realLLM.resetConversation()
        
        outputText = ""
        error = nil
        isGenerating = false
    }
    
    // Expose stateful LLM loading status for UI
    var realLLMLoadingStatus: String {
        if realLLM.isLoaded {
            return "✅ Stateful LLM Loaded (Apple's KV Cache)"
        } else if let error = realLLM.error {
            return "❌ Stateful LLM Error: \(error)"
        } else {
            return "⏳ Loading Stateful LLM with KV Cache..."
        }
    }
} 