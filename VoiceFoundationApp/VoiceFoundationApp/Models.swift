import Foundation
import SwiftUI

// MARK: - Message Models
struct Message: Identifiable, Codable {
    let id: UUID
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let isError: Bool
    
    init(content: String, isFromUser: Bool, isError: Bool = false) {
        self.id = UUID()
        self.content = content
        self.isFromUser = isFromUser
        self.timestamp = Date()
        self.isError = isError
    }
}

// MARK: - Conversation Models
struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [Message]
    let createdAt: Date
    var updatedAt: Date
    
    init(title: String = "New Conversation") {
        self.id = UUID()
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    mutating func addMessage(_ message: Message) {
        messages.append(message)
        updatedAt = Date()
        
        // Auto-generate title from first user message if needed
        if title == "New Conversation", message.isFromUser, !message.content.isEmpty {
            title = String(message.content.prefix(50)) + (message.content.count > 50 ? "..." : "")
        }
    }
    
    var lastMessage: Message? {
        messages.last
    }
    
    var preview: String {
        lastMessage?.content ?? "No messages"
    }
}

// MARK: - App Settings
struct AppSettings: Codable {
    var useMockLLM: Bool = false  // Default to real LLM mode
    var voiceSpeed: Double = 0.55  // Slightly faster for more natural speech
    var voicePitch: Double = 1.0
    var autoSpeak: Bool = true
    var keepScreenOn: Bool = false
    var preferredVoice: String = "en-US"
    var theme: AppTheme = .dark
    var exportLocation: String = ""  // Custom export location
    var useCustomStorageLocation: Bool = false
    var customStorageLocation: String = ""  // Custom storage location
    
    enum AppTheme: String, CaseIterable, Codable {
        case light = "light"
        case dark = "dark"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "System"
            }
        }
    }
}

// MARK: - LLM Response Types
enum LLMMode {
    case mock  // Temporary mock responses
    case real  // Real model when ready
} 