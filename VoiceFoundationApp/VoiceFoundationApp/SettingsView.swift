import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var conversationManager: ConversationManager
    @State private var showingAbout = false
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var speechSynthesizer: AVSpeechSynthesizer?
    @State private var showingExportLocationPicker = false
    @State private var showingStorageLocationPicker = false
    @State private var isExporting = false
    
    var body: some View {
        NavigationStack {
            Form {
                // AI Model Section
                Section(header: Text("AI Model")) {
                    HStack {
                        Image(systemName: conversationManager.settings.useMockLLM ? "circle.dotted" : "brain.head.profile")
                            .foregroundColor(conversationManager.settings.useMockLLM ? .orange : .green)
                        
                        VStack(alignment: .leading) {
                            Text("AI Assistant")
                                .font(.headline)
                            Text(conversationManager.settings.useMockLLM ? "Demo Mode" : "Real AI Model")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("AI Mode", selection: Binding<Bool>(
                            get: { conversationManager.settings.useMockLLM },
                            set: { newValue in
                                var settings = conversationManager.settings
                                settings.useMockLLM = newValue
                                conversationManager.updateSettings(settings)
                            }
                        )) {
                            Text("Real AI").tag(false)
                            Text("Demo").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 120)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if conversationManager.settings.useMockLLM {
                            Label("Testing with intelligent demo responses", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Label("Using on-device Gemma-2B-IT model", systemImage: "checkmark.circle")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Test Real LLM Button
                    if !conversationManager.settings.useMockLLM {
                        Button(action: testRealLLM) {
                            HStack {
                                Image(systemName: "flask.fill")
                                Text("Test Stateful LLM")
                            }
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Voice & Speech Section
                Section(header: Text("Voice & Speech")) {
                    // Auto-speak toggle
                    HStack {
                        Image(systemName: "speaker.wave.2")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Auto-speak Responses")
                            Text("Automatically read AI responses aloud")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding<Bool>(
                            get: { conversationManager.settings.autoSpeak },
                            set: { newValue in
                                var settings = conversationManager.settings
                                settings.autoSpeak = newValue
                                conversationManager.updateSettings(settings)
                            }
                        ))
                    }
                    
                    // Voice speed
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(.green)
                            Text("Speech Speed")
                            Spacer()
                            Text("\(String(format: "%.0f", conversationManager.settings.voiceSpeed * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding<Double>(
                                get: { conversationManager.settings.voiceSpeed },
                                set: { newValue in
                                    var settings = conversationManager.settings
                                    settings.voiceSpeed = newValue
                                    conversationManager.updateSettings(settings)
                                }
                            ),
                            in: 0.3...1.0,
                            label: {
                                Text("Speed")
                            },
                            minimumValueLabel: {
                                Text("30%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            },
                            maximumValueLabel: {
                                Text("100%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            },
                            onEditingChanged: { isEditing in
                                if !isEditing {
                                    // Preview the speed when user finishes adjusting
                                    previewCurrentSettings()
                                }
                            }
                        )
                    }
                    
                    // Voice pitch
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "tuningfork")
                                .foregroundColor(.purple)
                            Text("Speech Pitch")
                            Spacer()
                            Text("\(String(format: "%.0f", conversationManager.settings.voicePitch * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: Binding<Double>(
                                get: { conversationManager.settings.voicePitch },
                                set: { newValue in
                                    var settings = conversationManager.settings
                                    settings.voicePitch = newValue
                                    conversationManager.updateSettings(settings)
                                }
                            ),
                            in: 0.5...2.0,
                            label: {
                                Text("Pitch")
                            },
                            minimumValueLabel: {
                                Text("50%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            },
                            maximumValueLabel: {
                                Text("200%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            },
                            onEditingChanged: { isEditing in
                                if !isEditing {
                                    // Preview the pitch when user finishes adjusting
                                    previewCurrentSettings()
                                }
                            }
                        )
                    }
                    
                    // Voice selection
                    NavigationLink(destination: VoiceSelectionView(conversationManager: conversationManager)) {
                        HStack {
                            Image(systemName: "person.wave.2")
                                .foregroundColor(.indigo)
                            
                            VStack(alignment: .leading) {
                                Text("Voice")
                                Text(getVoiceDisplayName())
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("Tap to preview and change voice")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Appearance Section
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: Binding<AppSettings.AppTheme>(
                        get: { conversationManager.settings.theme },
                        set: { newValue in
                            var settings = conversationManager.settings
                            settings.theme = newValue
                            conversationManager.updateSettings(settings)
                        }
                    )) {
                        ForEach(AppSettings.AppTheme.allCases, id: \.self) { theme in
                            HStack {
                                Image(systemName: themeIcon(for: theme))
                                Text(theme.displayName)
                            }
                            .tag(theme)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Device & Performance Section
                Section(header: Text("Device & Performance")) {
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading) {
                            Text("Keep Screen On")
                            Text("Prevent screen from sleeping during conversations")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding<Bool>(
                            get: { conversationManager.settings.keepScreenOn },
                            set: { newValue in
                                var settings = conversationManager.settings
                                settings.keepScreenOn = newValue
                                conversationManager.updateSettings(settings)
                                
                                // Apply the setting immediately
                                UIApplication.shared.isIdleTimerDisabled = newValue
                            }
                        ))
                    }
                    
                    // Device info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.orange)
                            Text("Neural Engine")
                            Spacer()
                            Text("Available")
                                .foregroundColor(.green)
                        }
                        
                        HStack {
                            Image(systemName: "memorychip")
                                .foregroundColor(.blue)
                            Text("Device Model")
                            Spacer()
                            Text(getDeviceModel())
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Data Section
                Section(header: Text("Data")) {
                    // Conversation count
                    HStack {
                        Image(systemName: "tray.full")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Conversation History")
                            Text("\(conversationManager.conversations.count) conversations stored")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Storage location setting
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "externaldrive")
                                .foregroundColor(.purple)
                            
                            VStack(alignment: .leading) {
                                Text("Storage Location")
                                Text(conversationManager.settings.useCustomStorageLocation ? 
                                    (conversationManager.settings.customStorageLocation.isEmpty ? "Custom location not set" : "Custom location") : 
                                    "Default (App Storage)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: Binding<Bool>(
                                get: { conversationManager.settings.useCustomStorageLocation },
                                set: { newValue in
                                    var settings = conversationManager.settings
                                    settings.useCustomStorageLocation = newValue
                                    conversationManager.updateSettings(settings)
                                    
                                    if newValue {
                                        showingStorageLocationPicker = true
                                    }
                                }
                            ))
                        }
                        
                        if conversationManager.settings.useCustomStorageLocation {
                            Button("Choose Storage Location") {
                                showingStorageLocationPicker = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    // Export location setting
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading) {
                                Text("Export Location")
                                Text(conversationManager.settings.exportLocation.isEmpty ? 
                                    "Documents folder" : 
                                    "Custom location")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button("Choose Export Location") {
                            showingExportLocationPicker = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    // Export button
                    Button(action: {
                        exportConversations()
                    }) {
                        HStack {
                            if isExporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Exporting...")
                            } else {
                                Image(systemName: "square.and.arrow.up.on.square")
                                Text("Export All Conversations")
                            }
                        }
                    }
                    .foregroundColor(.blue)
                    .disabled(isExporting || conversationManager.conversations.isEmpty)
                }
                
                // About Section
                Section(header: Text("About")) {
                    Button("About Veda") {
                        showingAbout = true
                    }
                    .foregroundColor(.blue)
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(getAppVersion())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadAvailableVoices()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingExportLocationPicker) {
                DocumentPickerView(isPresented: $showingExportLocationPicker) { url in
                    var settings = conversationManager.settings
                    settings.exportLocation = url.path
                    conversationManager.updateSettings(settings)
                }
            }
            .sheet(isPresented: $showingStorageLocationPicker) {
                DocumentPickerView(isPresented: $showingStorageLocationPicker) { url in
                    var settings = conversationManager.settings
                    settings.customStorageLocation = url.path
                    conversationManager.updateSettings(settings)
                }
            }
        }
    }
    
    private func getVoiceDisplayName() -> String {
        let voice = availableVoices.first { $0.language == conversationManager.settings.preferredVoice }
        return voice?.name ?? "Default"
    }
    
    private func themeIcon(for theme: AppSettings.AppTheme) -> String {
        switch theme {
        case .light: return "sun.max"
        case .dark: return "moon"
        case .system: return "gear"
        }
    }
    
    private func loadAvailableVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
    }
    
    private func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                ptr in String.init(validatingUTF8: ptr)
            }
        }
        return modelCode ?? "Unknown"
    }
    
    private func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private func exportConversations() {
        isExporting = true
        
        Task {
            do {
                let exportedFiles = try await exportAllConversations()
                
                await MainActor.run {
                    isExporting = false
                    print("✅ Exported \(exportedFiles.count) conversation files successfully")
                    
                    // Show success feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    print("❌ Export failed: \(error)")
                }
            }
        }
    }
    
    private func exportAllConversations() async throws -> [URL] {
        let conversations = conversationManager.conversations
        var exportedFiles: [URL] = []
        
        // Determine export directory
        let exportDirectory: URL
        if !conversationManager.settings.exportLocation.isEmpty {
            exportDirectory = URL(fileURLWithPath: conversationManager.settings.exportLocation)
        } else {
            exportDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        
                        // Create Veda folder
                let vedaFolder = exportDirectory.appendingPathComponent("Veda Conversations")
        try FileManager.default.createDirectory(at: vedaFolder, withIntermediateDirectories: true)
        
        // Export each conversation
        for conversation in conversations {
            let fileName = sanitizeFileName(conversation.title)
            let fileURL = vedaFolder.appendingPathComponent("\(fileName).md")
            
            let markdown = generateMarkdown(for: conversation)
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            exportedFiles.append(fileURL)
        }
        
        // Create a summary file
        let summaryURL = vedaFolder.appendingPathComponent("_Export_Summary.md")
        let summary = generateExportSummary(conversations: conversations, exportedFiles: exportedFiles)
        try summary.write(to: summaryURL, atomically: true, encoding: .utf8)
        exportedFiles.append(summaryURL)
        
        return exportedFiles
    }
    
    private func generateMarkdown(for conversation: Conversation) -> String {
        var markdown = ""
        
        // Header
        markdown += "# \(conversation.title)\n\n"
        markdown += "**Created:** \(DateFormatter.fullDateTime.string(from: conversation.createdAt))\n"
        markdown += "**Last Updated:** \(DateFormatter.fullDateTime.string(from: conversation.updatedAt))\n"
        markdown += "**Messages:** \(conversation.messages.count)\n\n"
        markdown += "---\n\n"
        
        // Messages
        for message in conversation.messages {
            let speaker = message.isFromUser ? "👤 **You**" : "🤖 **Assistant**"
            let timestamp = DateFormatter.timeOnly.string(from: message.timestamp)
            
            markdown += "\(speaker) *(\(timestamp))*\n\n"
            
            if message.isError {
                markdown += "❌ **Error:** \(message.content)\n\n"
            } else {
                markdown += "\(message.content)\n\n"
            }
            
            markdown += "---\n\n"
        }
        
        return markdown
    }
    
    private func generateExportSummary(conversations: [Conversation], exportedFiles: [URL]) -> String {
        var summary = ""
        
                    summary += "# Veda Export Summary\n\n"
        summary += "**Export Date:** \(DateFormatter.fullDateTime.string(from: Date()))\n"
        summary += "**Total Conversations:** \(conversations.count)\n"
        summary += "**Total Files Created:** \(exportedFiles.count)\n\n"
        
        summary += "## Conversations Exported\n\n"
        
        for conversation in conversations {
            summary += "- **\(conversation.title)**\n"
            summary += "  - Created: \(DateFormatter.fullDateTime.string(from: conversation.createdAt))\n"
            summary += "  - Messages: \(conversation.messages.count)\n"
            summary += "  - File: `\(sanitizeFileName(conversation.title)).md`\n\n"
        }
        
        summary += "## Statistics\n\n"
        let totalMessages = conversations.reduce(0) { $0 + $1.messages.count }
        let userMessages = conversations.flatMap { $0.messages }.filter { $0.isFromUser }.count
        let assistantMessages = totalMessages - userMessages
        
        summary += "- **Total Messages:** \(totalMessages)\n"
        summary += "- **User Messages:** \(userMessages)\n"
        summary += "- **Assistant Messages:** \(assistantMessages)\n"
        summary += "- **Average Messages per Conversation:** \(totalMessages / max(conversations.count, 1))\n\n"
        
        summary += "---\n\n"
                    summary += "*Exported from Veda App*\n"
        
        return summary
    }
    
    private func sanitizeFileName(_ fileName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return fileName
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(100)
            .description
    }
    
    private func previewCurrentSettings() {
        // Initialize synthesizer if needed
        if speechSynthesizer == nil {
            speechSynthesizer = AVSpeechSynthesizer()
        }
        
        // Stop any current speech
        if speechSynthesizer?.isSpeaking == true {
            speechSynthesizer?.stopSpeaking(at: .immediate)
        }
        
        // Create preview utterance with current settings
        let previewText = "Voice speed \(Int(conversationManager.settings.voiceSpeed * 100)) percent, pitch \(Int(conversationManager.settings.voicePitch * 100)) percent"
        let utterance = AVSpeechUtterance(string: previewText)
        
        // Apply current settings
        if let voice = AVSpeechSynthesisVoice(language: conversationManager.settings.preferredVoice) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        utterance.rate = Float(conversationManager.settings.voiceSpeed)
        utterance.pitchMultiplier = Float(conversationManager.settings.voicePitch)
        utterance.volume = 0.8
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session for settings preview: \(error)")
        }
        
        speechSynthesizer?.speak(utterance)
    }
    
    private func testRealLLM() {
        print("🧪 Testing Real LLM directly...")
        
        // Create a test instance
                        let testLLM = StatefulLLMManager()
        
        // Wait a bit for model to load, then test
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            print("🧪 Attempting test generation...")
            testLLM.generateResponse(for: "Hello, this is a test.")
        }
    }
}

// MARK: - Voice Selection View
struct VoiceSelectionView: View {
    @ObservedObject var conversationManager: ConversationManager
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    @State private var previewingSpeech = false
    @State private var currentPreviewVoice: String?
    @State private var voicePreviewDelegate: VoicePreviewDelegate?
    @State private var speechSynthesizer: AVSpeechSynthesizer?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            ForEach(availableVoices, id: \.language) { voice in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(voice.name)
                                .font(.headline)
                            
                            Text(voice.language)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Quality: \(voice.quality.description)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Preview button
                        Button(action: {
                            previewVoice(voice)
                        }) {
                            Image(systemName: currentPreviewVoice == voice.language ? "speaker.wave.2.fill" : "play.circle")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                        .disabled(previewingSpeech && currentPreviewVoice != voice.language)
                        
                        if voice.language == conversationManager.settings.preferredVoice {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .font(.title2)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectVoice(voice)
                }
            }
        }
        .navigationTitle("Select Voice")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Filter to English voices, prefer high-quality but include default if needed
            let allEnglishVoices = AVSpeechSynthesisVoice.speechVoices()
                .filter { $0.language.hasPrefix("en") }
            
            // Try to get high-quality voices first
            let highQualityVoices = allEnglishVoices.filter { 
                $0.quality == .enhanced || $0.quality == .premium 
            }
            
            // Use high-quality voices if available, otherwise fall back to all English voices
            availableVoices = (highQualityVoices.isEmpty ? allEnglishVoices : highQualityVoices)
                .sorted { voice1, voice2 in
                    // Sort by quality first (premium > enhanced > default), then by name
                    if voice1.quality != voice2.quality {
                        return voice1.quality.rawValue > voice2.quality.rawValue
                    }
                    return voice1.name < voice2.name
                }
        }
    }
    
    private func selectVoice(_ voice: AVSpeechSynthesisVoice) {
        var settings = conversationManager.settings
        settings.preferredVoice = voice.language
        conversationManager.updateSettings(settings)
        dismiss()
    }
    
    private func previewVoice(_ voice: AVSpeechSynthesisVoice) {
        guard !previewingSpeech else { return }
        
        previewingSpeech = true
        currentPreviewVoice = voice.language
        
        // Create a preview utterance
        let previewText = "Hi, I'm \(voice.name). This is how I sound with natural speech settings."
        let utterance = AVSpeechUtterance(string: previewText)
        utterance.voice = voice
        utterance.rate = Float(max(0.4, min(0.7, conversationManager.settings.voiceSpeed))) // More natural range
        utterance.pitchMultiplier = Float(max(0.8, min(1.3, conversationManager.settings.voicePitch))) // More natural range
        utterance.volume = 1.0
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session for voice preview: \(error)")
            previewingSpeech = false
            currentPreviewVoice = nil
            return
        }
        
        // Create delegate and synthesizer if needed
        if speechSynthesizer == nil {
            speechSynthesizer = AVSpeechSynthesizer()
        }
        
        voicePreviewDelegate = VoicePreviewDelegate {
            Task { @MainActor in
                self.previewingSpeech = false
                self.currentPreviewVoice = nil
            }
        }
        
        speechSynthesizer?.delegate = voicePreviewDelegate
        speechSynthesizer?.speak(utterance)
    }
}

// MARK: - Voice Preview Delegate
class VoicePreviewDelegate: NSObject, AVSpeechSynthesizerDelegate {
    private let onFinished: () -> Void
    
    init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
        super.init()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        onFinished()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        onFinished()
    }
}

// MARK: - About View
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 8) {
                        Text("Veda")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("On-Device AI Assistant")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "brain.head.profile",
                            title: "On-Device AI",
                            description: "Powered by Apple's Neural Engine for fast, private responses"
                        )
                        
                        FeatureRow(
                            icon: "lock.shield",
                            title: "Privacy First",
                            description: "All conversations stay on your device - nothing is sent to servers"
                        )
                        
                        FeatureRow(
                            icon: "mic.and.signal.meter",
                            title: "Voice Interface",
                            description: "Natural speech recognition and text-to-speech capabilities"
                        )
                        
                        FeatureRow(
                            icon: "clock.arrow.circlepath",
                            title: "Conversation History",
                            description: "All your conversations are saved locally and searchable"
                        )
                    }
                    .padding()
                    
                    VStack(spacing: 12) {
                        Text("Built with")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            TechLabel(name: "SwiftUI", color: .blue)
                            TechLabel(name: "Core ML", color: .green)
                            TechLabel(name: "Speech", color: .orange)
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct TechLabel: View {
    let name: String
    let color: Color
    
    var body: some View {
        Text(name)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

// Extension for voice quality description
extension AVSpeechSynthesisVoiceQuality {
    var description: String {
        switch self {
        case .default:
            return "Default"
        case .enhanced:
            return "Enhanced"
        case .premium:
            return "Premium"
        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Document Picker
struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onSelection: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onSelection(url)
            }
            parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

// MARK: - DateFormatter Extensions
extension DateFormatter {
    static let fullDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter
    }()
    
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    SettingsView(conversationManager: ConversationManager())
} 
