import SwiftUI

struct ConversationHistoryView: View {
    @ObservedObject var conversationManager: ConversationManager
    @State private var searchText = ""
    @State private var showingDeleteAlert = false
    @State private var conversationToDelete: Conversation?
    
    var filteredConversations: [Conversation] {
        if searchText.isEmpty {
            return conversationManager.conversations
        } else {
            return conversationManager.searchConversations(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if conversationManager.conversations.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                            .opacity(0.6)
                        
                        VStack(spacing: 8) {
                            Text("No Conversations Yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Your conversation history will appear here")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 100)
                } else {
                    // Conversations list
                    List {
                        ForEach(filteredConversations) { conversation in
                            NavigationLink(destination: ConversationDetailView(
                                conversation: conversation,
                                conversationManager: conversationManager
                            )) {
                                ConversationRow(
                                    conversation: conversation,
                                    isCurrentConversation: conversationManager.currentConversation?.id == conversation.id,
                                    onTap: {
                                        conversationManager.loadConversation(conversation)
                                    },
                                    onDelete: {
                                        conversationToDelete = conversation
                                        showingDeleteAlert = true
                                    }
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .listStyle(PlainListStyle())
                    .searchable(text: $searchText, prompt: "Search conversations...")
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !conversationManager.conversations.isEmpty {
                        Menu {
                            Button("Clear All History", role: .destructive) {
                                showingClearAllAlert()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("Delete Conversation?", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    conversationToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let conversation = conversationToDelete {
                        conversationManager.deleteConversation(conversation)
                    }
                    conversationToDelete = nil
                }
            } message: {
                Text("This conversation will be permanently deleted.")
            }
        }
    }
    
    private func showingClearAllAlert() {
        let alert = UIAlertController(
            title: "Clear All History?",
            message: "This will permanently delete all conversations.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { _ in
            conversationManager.clearAllConversations()
        })
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(alert, animated: true)
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let isCurrentConversation: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(conversation.title)
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(isCurrentConversation ? .blue : .primary)
                    
                    if isCurrentConversation {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }
                    
                    Spacer()
                }
                
                if let lastMessage = conversation.lastMessage {
                    Text(lastMessage.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    Text(conversation.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(conversation.messages.count) message\(conversation.messages.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 8)
        .background(isCurrentConversation ? Color.blue.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ConversationHistoryView(conversationManager: ConversationManager())
}

// MARK: - Conversation Detail View
struct ConversationDetailView: View {
    let conversation: Conversation
    @ObservedObject var conversationManager: ConversationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(conversation.messages) { message in
                        DetailMessageBubble(message: message)
                    }
                }
                .padding()
            }
            .navigationTitle(conversation.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Continue This Conversation") {
                            conversationManager.loadConversation(conversation)
                            dismiss()
                        }
                        
                        Divider()
                        
                        Button("Delete Conversation", role: .destructive) {
                            conversationManager.deleteConversation(conversation)
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

// MARK: - Detail Message Bubble (optimized for reading)
struct DetailMessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 6) {
                HStack {
                    if !message.isFromUser {
                        Text("Assistant")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if message.isFromUser {
                        Text("You")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isFromUser {
                Spacer(minLength: 50)
            }
        }
    }
    
    private var backgroundColor: Color {
        if message.isError {
            return .red.opacity(0.2)
        }
        return message.isFromUser ? .blue : Color(.systemGray5)
    }
    
    private var textColor: Color {
        if message.isError {
            return .red
        }
        return message.isFromUser ? .white : .primary
    }
} 