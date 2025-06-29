//
//  ContentView.swift
//  VoiceFoundationApp
//
//  Created by Raviteja on 6/22/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var conversationManager = ConversationManager()
    @StateObject private var speechManager = SpeechManager()
    @StateObject private var llmManager = UnifiedLLMManager()
    
    var currentLLMManager: UnifiedLLMManager {
        return llmManager
    }
    
    var body: some View {
        TabView {
            // Main conversation view
            MainChatView(
                conversationManager: conversationManager,
                speechManager: speechManager,
                llmManager: currentLLMManager
            )
            .tabItem {
                Label("Chat", systemImage: "message.fill")
            }

            // Conversation History View
            ConversationHistoryView(conversationManager: conversationManager)
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            
            // Settings View
            SettingsView(conversationManager: conversationManager)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .preferredColorScheme(conversationManager.settings.theme == .dark ? .dark : 
                             conversationManager.settings.theme == .light ? .light : nil)
    }
}

// MARK: - Main Chat View with Text Input and Voice Mode
struct MainChatView: View {
    @ObservedObject var conversationManager: ConversationManager
    @ObservedObject var speechManager: SpeechManager
    @ObservedObject var llmManager: UnifiedLLMManager
    
    @State private var textInput = ""
    @State private var isVoiceModeActive = false
    @State private var showingNewChatAlert = false
    @State private var pendingNewChat = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Chat Messages Area
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if let conversation = conversationManager.currentConversation {
                                    ForEach(conversation.messages) { message in
                                        MessageBubble(message: message)
                                            .id(message.id)
                                    }
                                }
                                
                                // Show current AI response being generated
                                if llmManager.isGenerating || !llmManager.outputText.isEmpty {
                                    MessageBubble(
                                        message: Message(
                                            content: llmManager.outputText.isEmpty ? "Thinking..." : llmManager.outputText,
                                            isFromUser: false
                                        ),
                                        isGenerating: llmManager.isGenerating
                                    )
                                    .id("generating")
                                }
                                
                                // Show error if any
                                if let error = llmManager.error, !error.isEmpty {
                                    MessageBubble(
                                        message: Message(content: "Error: \(error)", isFromUser: false, isError: true)
                                    )
                                }
                                
                                // Empty state
                                if conversationManager.currentConversation?.messages.isEmpty ?? true {
                                    EmptyStateView()
                                }
                            }
                            .padding()
                            .padding(.bottom, isVoiceModeActive ? 20 : 100) // Space for input bar
                        }
                        .onChange(of: conversationManager.currentConversation?.messages.count) { _, _ in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                if let lastMessageId = conversationManager.currentConversation?.messages.last?.id {
                                    proxy.scrollTo(lastMessageId, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: llmManager.outputText) { _, _ in
                            withAnimation(.easeInOut(duration: 0.3)) {
                                proxy.scrollTo("generating", anchor: .bottom)
                            }
                        }
                    }
                    
                    // Text Input Bar (hidden in voice mode)
                    if !isVoiceModeActive {
                        TextInputBar(
                            text: $textInput,
                            onSend: { text in
                                handleTextInput(text)
                                textInput = ""
                            },
                            onVoiceMode: {
                                withAnimation(.spring()) {
                                    isVoiceModeActive = true
                                }
                            }
                        )
                        .background(Color(.systemBackground))
                    }
                }
                
                // Fullscreen Voice Mode Overlay
                if isVoiceModeActive {
                    VoiceModeView(
                        speechManager: speechManager,
                        isActive: $isVoiceModeActive,
                        onVoiceInput: handleVoiceInput
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(Color(.systemBackground))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if conversationManager.currentConversation?.title == "New Conversation" || conversationManager.currentConversation?.title == nil {
                        // Show logo for new conversations
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 28)
                    } else {
                        // Show conversation title for named conversations
                        Text(conversationTitle)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("New", action: { 
                        if conversationManager.hasActiveConversation {
                            pendingNewChat = true
                            showingNewChatAlert = true
                        } else {
                            startNewChat()
                        }
                    })
                    .foregroundColor(.blue)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        // Stop speaking button (only when speaking)
                        if speechManager.isSpeaking {
                            Button(action: {
                                speechManager.stopSpeaking()
                            }) {
                                Image(systemName: "stop.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.title3)
                            }
                        }
                        
                        // Mute/Unmute button
                        Button(action: {
                            speechManager.toggleMute()
                        }) {
                            Image(systemName: speechManager.isMuted ? "speaker.slash.fill" : "speaker.2.fill")
                                .foregroundColor(speechManager.isMuted ? .gray : .blue)
                                .font(.title3)
                        }
                        
                        Circle()
                            .fill(conversationManager.settings.useMockLLM ? .orange : .green)
                            .frame(width: 8, height: 8)
                        
                        Text(conversationManager.settings.useMockLLM ? "Demo" : "AI")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .alert("Start New Conversation?", isPresented: $showingNewChatAlert) {
                Button("Cancel", role: .cancel) { 
                    pendingNewChat = false
                }
                Button("Save & New Chat") {
                    if pendingNewChat {
                        conversationManager.saveCurrentConversation()
                        conversationManager.startNewConversation()
                        llmManager.resetConversation()
                        pendingNewChat = false
                    }
                }
                Button("Discard & New Chat", role: .destructive) {
                    if pendingNewChat {
                        conversationManager.discardCurrentConversation()
                        llmManager.resetConversation()
                        pendingNewChat = false
                    }
                }
            } message: {
                Text("Would you like to save the current conversation before starting a new one?")
            }
        }
        .onAppear {
            speechManager.requestPermissions()
            if conversationManager.currentConversation == nil {
                conversationManager.startNewConversation()
            }
            
            // Initialize LLM mode based on settings
            llmManager.updateMode(useMock: conversationManager.settings.useMockLLM)
            
            // Set up streaming TTS callback
            llmManager.onStreamingText = { [weak speechManager, weak conversationManager] streamingText in
                guard let speechManager = speechManager, let conversationManager = conversationManager else { return }
                
                if conversationManager.settings.autoSpeak || self.isVoiceModeActive {
                    speechManager.updateStreamingText(streamingText, settings: conversationManager.settings)
                }
            }
            
            // Set up direct TTS callback for completion
            llmManager.onResponseComplete = { [weak speechManager, weak conversationManager] responseText in
                print("🔊 Response complete callback triggered")
                guard let speechManager = speechManager, let conversationManager = conversationManager else { return }
                
                // Speak any remaining content that wasn't spoken during streaming
                if conversationManager.settings.autoSpeak || self.isVoiceModeActive {
                    speechManager.finishStreamingTTS(finalText: responseText, settings: conversationManager.settings)
                } else {
                    speechManager.cleanupStreamingState()
                }
            }
        }
        .onChange(of: llmManager.outputText) { _, newOutput in
            if !llmManager.isGenerating && !newOutput.isEmpty {
                print("📝 LLM output finished: '\(newOutput)'")
                conversationManager.addMessage(newOutput, isFromUser: false)
            }
        }
        .onChange(of: llmManager.isGenerating) { _, isGenerating in
            print("📝 LLM generating state changed: \(isGenerating)")
            // Clear processing state when LLM finishes
            if !isGenerating {
                // Clear any processing states in voice mode
                // This will be handled by the VoiceModeView through the speech manager
            }
        }
        .onChange(of: speechManager.isSpeaking) { _, isSpeaking in
            // When TTS finishes and we're in voice mode, automatically close voice mode
            if !isSpeaking && isVoiceModeActive && !llmManager.isGenerating {
                print("🔊 TTS finished, closing voice mode in 1 second")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.spring()) {
                        isVoiceModeActive = false
                    }
                    // Provide haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
        }
        .onChange(of: conversationManager.settings.useMockLLM) { _, useMock in
            // Update LLM mode when settings change
            llmManager.updateMode(useMock: useMock)
        }
    }
    
    private var conversationTitle: String {
        if let title = conversationManager.currentConversation?.title, title != "New Conversation" {
            return title
        }
        return "Veda"
    }
    
    private func startNewChat() {
        // Clear current LLM output
        llmManager.resetConversation()
        conversationManager.startNewConversation()
    }
    
    private func testTTS() {
        print("🔊 Manual TTS Test - Testing direct TTS call")
        speechManager.speak("This is a test of the text to speech system. Can you hear me?", settings: conversationManager.settings)
    }
    
    private func saveCurrentLLMResponse() {
        // Save any existing LLM output that hasn't been saved yet
        if !llmManager.isGenerating && !llmManager.outputText.isEmpty {
            // Check if this response is already saved
            let lastMessage = conversationManager.currentConversation?.messages.last
            if lastMessage?.content != llmManager.outputText {
                print("📝 Saving previous LLM response: '\(llmManager.outputText)'")
                conversationManager.addMessage(llmManager.outputText, isFromUser: false)
            }
        }
    }
    
    private func handleTextInput(_ text: String) {
        // Save any existing LLM output before generating new response
        saveCurrentLLMResponse()
        
        conversationManager.addMessage(text, isFromUser: true)
        
        // Start streaming TTS if auto-speak is enabled
        if conversationManager.settings.autoSpeak {
            speechManager.startStreamingTTS(settings: conversationManager.settings)
        }
        
        llmManager.generateResponse(for: text)
    }
    
    private func handleVoiceInput(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        print("🎤 Voice input received: '\(trimmedText)'")
        
        // Save any existing LLM output before generating new response
        saveCurrentLLMResponse()
        
        conversationManager.addMessage(trimmedText, isFromUser: true)
        
        // Always start streaming TTS for voice mode
        speechManager.startStreamingTTS(settings: conversationManager.settings)
        
        llmManager.generateResponse(for: trimmedText)
        
        // Clear transcribed text to prevent duplicates
        DispatchQueue.main.async {
            self.speechManager.transcribedText = ""
        }
    }
}

// MARK: - Text Input Bar
struct TextInputBar: View {
    @Binding var text: String
    let onSend: (String) -> Void
    let onVoiceMode: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                TextField("Ask anything...", text: $text)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                
                if !text.isEmpty {
                    Button(action: {
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSend(text)
                        }
                    }) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing, 8)
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            
            // Voice Mode Button
            Button(action: onVoiceMode) {
                Image(systemName: "mic.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// MARK: - Fullscreen Voice Mode (Perplexity-style)
struct VoiceModeView: View {
    @ObservedObject var speechManager: SpeechManager
    @Binding var isActive: Bool
    let onVoiceInput: (String) -> Void
    
    @State private var isListening = false
    @State private var waveformAmplitudes: [CGFloat] = Array(repeating: 0.1, count: 50)
    @State private var animationTimer: Timer?
    @State private var timeoutTimer: Timer?
    @State private var isProcessingVoice = false
    
    var body: some View {
        VStack(spacing: 40) {
            // Top controls
            HStack {
                // Stop speaking button
                if speechManager.isSpeaking {
                    Button(action: {
                        speechManager.stopSpeaking()
                    }) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop Speaking")
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                // Close button
                Button(action: {
                    stopListening()
                    speechManager.stopSpeaking()
                    withAnimation(.spring()) {
                        isActive = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            Spacer()
            
            // Status text
            VStack(spacing: 16) {
                Text(getStatusText())
                    .font(.title2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                
                if !speechManager.transcribedText.isEmpty {
                    Text(speechManager.transcribedText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal)
            
            // Animated Waveform (when speaking/listening)
            if isListening || speechManager.isSpeaking {
                WaveformView(amplitudes: waveformAmplitudes, isActive: isListening || speechManager.isSpeaking)
                    .frame(height: 60)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Large microphone button
            Button(action: toggleListening) {
                ZStack {
                    Circle()
                        .fill(speechManager.isSpeaking ? .green : (isListening ? .red : .blue))
                        .frame(width: 120, height: 120)
                        .scaleEffect(isListening ? 1.1 : 1.0)
                        .opacity(isListening ? 0.8 : 1.0)
                        .overlay(
                            Circle()
                                .stroke(speechManager.isSpeaking ? Color.green.opacity(0.3) : (isListening ? Color.red.opacity(0.3) : Color.clear), lineWidth: 20)
                                .scaleEffect((isListening || speechManager.isSpeaking) ? 1.3 : 1.0)
                                .opacity((isListening || speechManager.isSpeaking) ? 0.6 : 0)
                        )
                    
                    if speechManager.isSpeaking {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(speechManager.isSpeaking)
            .animation(.easeInOut(duration: 0.3), value: isListening)
            .animation(.easeInOut(duration: 0.3), value: speechManager.isSpeaking)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isListening || speechManager.isSpeaking)
            
            Text(speechManager.isSpeaking ? "Speaking..." : (isListening ? "Tap to stop" : "Tap to speak"))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .onAppear {
            startListening()
        }
        .onDisappear {
            stopListening()
            stopWaveformAnimation()
            timeoutTimer?.invalidate()
            timeoutTimer = nil
            isProcessingVoice = false
        }
    }
    
    private func getStatusText() -> String {
        if speechManager.isSpeaking {
            return "🔊 Speaking..."
        } else if isListening {
            return "🎤 Listening..."
        } else if isProcessingVoice {
            return "🤖 Processing..."
        } else if !speechManager.transcribedText.isEmpty {
            return "📝 Ready to process..."
        } else {
            return "Tap the microphone to speak"
        }
    }
    
    private func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }
    
    private func startListening() {
        isListening = true
        speechManager.startTranscription()
        startWaveformAnimation()
    }
    
    private func stopListening() {
        guard isListening else { return }
        
        isListening = false
        speechManager.stopTranscription()
        stopWaveformAnimation()
        
        // Cancel any existing timeout
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        
        // Process transcribed text only if it's substantial
        let trimmedText = speechManager.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedText.isEmpty && trimmedText.count > 2 {
            print("🎤 Processing voice input: '\(trimmedText)'")
            isProcessingVoice = true
            onVoiceInput(trimmedText)
            
            // Set a timeout in case processing gets stuck
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                print("🎤 Voice processing timeout - resetting state")
                isProcessingVoice = false
            }
        } else {
            print("🎤 Voice input too short or empty, ignoring: '\(trimmedText)'")
        }
    }
    
    private func startWaveformAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            waveformAmplitudes = waveformAmplitudes.map { _ in
                CGFloat.random(in: 0.1...1.0)
            }
        }
    }
    
    private func stopWaveformAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        waveformAmplitudes = Array(repeating: 0.1, count: 50)
    }
}

// MARK: - Animated Waveform View
struct WaveformView: View {
    let amplitudes: [CGFloat]
    let isActive: Bool
    
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<amplitudes.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.blue)
                    .frame(width: 3)
                    .frame(height: amplitudes[index] * 60)
                    .animation(
                        .easeInOut(duration: 0.1)
                        .delay(Double(index) * 0.01),
                        value: amplitudes[index]
                    )
            }
        }
    }
}

// MARK: - Message Bubble Component
struct MessageBubble: View {
    let message: Message
    var isGenerating: Bool = false
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(backgroundColor)
                    .foregroundColor(textColor)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        isGenerating && !message.isFromUser ? 
                        TypingIndicator() : nil,
                        alignment: .trailing
                    )
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !message.isFromUser {
                Spacer(minLength: 50)
            }
        }
        .opacity(isGenerating ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: isGenerating)
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

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding(.horizontal, 8)
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Empty State
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .opacity(0.6)
            
            Text("I'm Veda, What's up!")
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding(.top, 50)
    }
}

#Preview {
    ContentView()
}
