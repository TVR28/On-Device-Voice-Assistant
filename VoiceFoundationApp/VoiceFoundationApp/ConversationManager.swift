import Foundation
import SwiftUI

@MainActor
class ConversationManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentConversation: Conversation?
    @Published var settings: AppSettings = AppSettings()
    
    private let userDefaults = UserDefaults.standard
    private let conversationsKey = "SavedConversations"
    private let settingsKey = "AppSettings"
    
    // Custom storage URLs
    private var conversationsFileURL: URL {
        if settings.useCustomStorageLocation && !settings.customStorageLocation.isEmpty {
            let customURL = URL(fileURLWithPath: settings.customStorageLocation)
            return customURL.appendingPathComponent("voice_assistant_conversations.json")
        } else {
            // Default: Documents directory
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            return documentsURL.appendingPathComponent("voice_assistant_conversations.json")
        }
    }
    
    private var settingsFileURL: URL {
        if settings.useCustomStorageLocation && !settings.customStorageLocation.isEmpty {
            let customURL = URL(fileURLWithPath: settings.customStorageLocation)
            return customURL.appendingPathComponent("voice_assistant_settings.json")
        } else {
            // Default: Documents directory
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            return documentsURL.appendingPathComponent("voice_assistant_settings.json")
        }
    }
    
    // File manager for custom storage locations
    private let fileManager = FileManager.default
    
    init() {
        loadData()
    }
    
    // MARK: - Conversation Management
    
    func startNewConversation() {
        let newConversation = Conversation()
        currentConversation = newConversation
    }
    
    func discardCurrentConversation() {
        // Simply start a new conversation without saving the current one
        currentConversation = nil
        startNewConversation()
    }
    
    func addMessage(_ content: String, isFromUser: Bool, isError: Bool = false) {
        let message = Message(content: content, isFromUser: isFromUser, isError: isError)
        
        if currentConversation == nil {
            startNewConversation()
        }
        
        currentConversation?.addMessage(message)
        // Don't auto-save here - let the user decide whether to save or discard
    }
    
    func saveCurrentConversation() {
        guard let current = currentConversation else { return }
        
        // Update existing conversation or add new one
        if let index = conversations.firstIndex(where: { $0.id == current.id }) {
            conversations[index] = current
        } else {
            conversations.insert(current, at: 0) // Add to beginning for recency
        }
        
        saveData()
    }
    
    func loadConversation(_ conversation: Conversation) {
        currentConversation = conversation
    }
    
    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        
        if currentConversation?.id == conversation.id {
            currentConversation = nil
        }
        
        saveData()
    }
    
    func clearAllConversations() {
        conversations.removeAll()
        currentConversation = nil
        saveData()
    }
    
    // MARK: - Settings Management
    
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        saveData()
    }
    
    // MARK: - Persistence
    
    private func saveData() {
        // Save conversations
        do {
            if settings.useCustomStorageLocation && !settings.customStorageLocation.isEmpty {
                // Save to custom location
                let encoded = try JSONEncoder().encode(conversations)
                
                // Ensure directory exists
                let directory = conversationsFileURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                
                try encoded.write(to: conversationsFileURL)
                print("💾 Conversations saved to custom location: \(conversationsFileURL.path)")
            } else {
                // Save to UserDefaults (default)
                let encoded = try JSONEncoder().encode(conversations)
                userDefaults.set(encoded, forKey: conversationsKey)
                print("💾 Conversations saved to UserDefaults")
            }
        } catch {
            print("❌ Failed to save conversations: \(error)")
            // Fallback to UserDefaults
            if let encoded = try? JSONEncoder().encode(conversations) {
                userDefaults.set(encoded, forKey: conversationsKey)
            }
        }
        
        // Save settings (always to UserDefaults for now)
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }
    
    private func loadData() {
        // Load settings first (always from UserDefaults)
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = decoded
            print("📱 Loaded settings from UserDefaults: useMockLLM = \(settings.useMockLLM)")
        } else {
            print("📱 Using default settings: useMockLLM = \(settings.useMockLLM)")
        }
        
        // TEMPORARY FIX: Force real LLM mode for testing
        settings.useMockLLM = false
        print("📱 FORCED: useMockLLM = \(settings.useMockLLM)")
        
        // Load conversations
        do {
            if settings.useCustomStorageLocation && !settings.customStorageLocation.isEmpty && FileManager.default.fileExists(atPath: conversationsFileURL.path) {
                // Load from custom location
                let data = try Data(contentsOf: conversationsFileURL)
                conversations = try JSONDecoder().decode([Conversation].self, from: data)
                print("📂 Conversations loaded from custom location: \(conversationsFileURL.path)")
            } else {
                // Load from UserDefaults (default)
                if let data = userDefaults.data(forKey: conversationsKey),
                   let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
                    conversations = decoded
                    print("📂 Conversations loaded from UserDefaults")
                }
            }
        } catch {
            print("❌ Failed to load conversations from custom location: \(error)")
            // Fallback to UserDefaults
            if let data = userDefaults.data(forKey: conversationsKey),
               let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
                conversations = decoded
                print("📂 Conversations loaded from UserDefaults (fallback)")
            }
        }
    }
    
    // MARK: - Storage Migration
    
    func migrateToCustomStorage() {
        // This will be called when user enables custom storage
        // Data will be saved to the new location on next save
        saveData()
    }
    
    func migrateToDefaultStorage() {
        // Move data back to UserDefaults
        settings.useCustomStorageLocation = false
        saveData()
    }
    
    // MARK: - Utility
    
    var hasActiveConversation: Bool {
        currentConversation != nil && !(currentConversation?.messages.isEmpty ?? true)
    }
    
    func searchConversations(_ query: String) -> [Conversation] {
        guard !query.isEmpty else { return conversations }
        
        return conversations.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(query) ||
            conversation.messages.contains { message in
                message.content.localizedCaseInsensitiveContains(query)
            }
        }
    }
} 