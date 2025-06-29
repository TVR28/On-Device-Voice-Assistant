import Foundation
import SwiftUI

@MainActor
class MockLLMManager: ObservableObject {
    @Published var outputText: String = ""
    @Published var isGenerating: Bool = false
    @Published var isLoaded: Bool = true // Mock is always "loaded"
    @Published var error: String?
    
    // Callback for when response is complete
    var onResponseComplete: ((String) -> Void)?
    
    // Callback for streaming TTS - called as text is being generated
    var onStreamingText: ((String) -> Void)?
    
    private let mockResponses = [
        "Hi! I'm Veda, your on-device AI assistant running in demo mode. All conversations are being saved to your device's local storage. How can I help you today?",
        "Great question! I'm currently demonstrating the conversation interface with sample responses. Your chat history is being stored locally on your iPhone and will persist between app launches.",
        "Thank you for testing Veda! The UI supports conversation bubbles, real-time typing effects, and complete conversation history. Everything is saved locally for privacy.",
        "I understand you'd like assistance. This demo showcases the full voice pipeline: speech recognition → text processing → text-to-speech output, all with persistent conversation storage.",
        "Perfect! The app includes advanced features like conversation search, voice settings customization, and theme options. All your conversations are automatically saved and organized.",
        "Excellent! I'm demonstrating the complete Veda experience with modern UI design inspired by ChatGPT and Perplexity. Your conversation history is fully persistent.",
        "Wonderful! This showcases the full feature set: voice input, intelligent responses, conversation management, settings customization, and local data persistence on your device."
    ]
    
    private let thinkingResponses = [
        "Let me think about that...",
        "Processing your request...",
        "Siri is thinking and will get back to you.",
        "Analyzing your question...",
        "Give me a moment to consider that...",
        "Working on a response for you...",
        "Let me process that information..."
    ]
    
    func generateResponse(for prompt: String) {
        guard !isGenerating else { return }
        
        isGenerating = true
        error = nil
        outputText = ""
        
        // Simulate thinking time
        Task {
            // Show thinking message first
            let thinkingMessage = thinkingResponses.randomElement() ?? "Thinking..."
            await MainActor.run {
                self.outputText = thinkingMessage
            }
            
            // Wait a bit to simulate processing
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // Generate contextual response
            let response = generateContextualResponse(for: prompt)
            
            await MainActor.run {
                // Simulate typing effect
                self.outputText = ""
                Task {
                    await self.typeResponse(response)
                }
            }
        }
    }
    
    private func generateContextualResponse(for prompt: String) -> String {
        let lowercasePrompt = prompt.lowercased()
        
        // Context-aware responses based on user input
        if lowercasePrompt.contains("hello") || lowercasePrompt.contains("hi") || lowercasePrompt.contains("hey") {
            return "Hello! Welcome to Veda demo. I'm showcasing the complete conversation interface with chat bubbles, conversation history, and voice synthesis. All conversations are stored locally on your device!"
        }
        
        if lowercasePrompt.contains("weather") {
            return "I'd love to help with weather! In the full version, I'll have real-time data access. Right now, I'm demonstrating the conversation flow and local storage capabilities. Try exploring the Settings and History tabs!"
        }
        
        if lowercasePrompt.contains("time") || lowercasePrompt.contains("clock") {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "The current time is \(formatter.string(from: Date())). This demonstrates real-time data integration. Notice how this conversation is automatically saved to your History tab with searchable content!"
        }
        
        if lowercasePrompt.contains("how are you") || lowercasePrompt.contains("how do you feel") {
            return "I'm doing great, thank you! I'm demonstrating Veda's conversation capabilities. Try testing different features like voice speed in Settings, or check out your conversation history in the History tab!"
        }
        
        if lowercasePrompt.contains("what can you do") || lowercasePrompt.contains("help") || lowercasePrompt.contains("features") {
            return "I'm showcasing the complete Veda experience! Features include: voice input/output, conversation bubbles, persistent chat history, searchable conversations, voice customization, theme options, and complete local data storage. Everything runs privately on your device!"
        }
        
        if lowercasePrompt.contains("test") || lowercasePrompt.contains("demo") {
            return "Perfect! You're testing the full Veda demo. This includes modern UI design, smooth animations, conversation management, voice synthesis with customizable settings, and complete data persistence. Try saying 'settings' to explore customization options!"
        }
        
        if lowercasePrompt.contains("settings") || lowercasePrompt.contains("customize") {
            return "Great idea! Check out the Settings tab to customize voice speed, pitch, choose different voices, change themes, and see device information. All your preferences are saved automatically!"
        }
        
        if lowercasePrompt.contains("history") || lowercasePrompt.contains("conversations") {
            return "Excellent! Your conversation history is automatically saved and organized in the History tab. You can search through all conversations, delete individual chats, or clear all history. Everything is stored locally for privacy!"
        }
        
        if lowercasePrompt.contains("thank") {
            return "You're very welcome! I hope this demonstrates the complete Veda experience. The app includes conversation persistence, voice customization, modern UI design, and seamless voice interaction - all running privately on your device!"
        }
        
        // Default response with some variation
        return mockResponses.randomElement() ?? "I'm showcasing the complete Veda experience with persistent conversations and modern UI design!"
    }
    
    private func typeResponse(_ response: String) async {
        let words = response.components(separatedBy: " ")
        outputText = ""
        
        for (index, word) in words.enumerated() {
            await MainActor.run {
                if index == 0 {
                    self.outputText = word
                } else {
                    self.outputText += " " + word
                }
                
                // Trigger streaming callback for TTS
                self.onStreamingText?(self.outputText)
            }
            
            // Simulate typing delay
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds per word
        }
        
        await MainActor.run {
            self.isGenerating = false
            // Trigger callback when response is complete
            self.onResponseComplete?(self.outputText)
        }
    }
    
    func resetConversation() {
        outputText = ""
        error = nil
        isGenerating = false
    }
} 