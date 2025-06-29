import Foundation
import Speech
import AVFoundation

/// A helper class to manage the Speech-to-Text and Text-to-Speech functionality.
/// It conforms to ObservableObject so that its published properties can be observed by SwiftUI views.
class SpeechManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// The transcribed text from the user's speech. The UI will update whenever this changes.
    @Published var transcribedText: String = ""
    
    /// A flag to indicate when the transcription has finished.
    @Published var isTranscriptionFinal: Bool = false
    
    /// Any error that occurs during the speech recognition process.
    @Published var error: Error?
    
    /// Indicates whether speech recognition is authorized.
    @Published var speechRecognitionAuthorized: Bool = false
    
    /// Indicates whether microphone access is authorized.
    @Published var microphoneAuthorized: Bool = false
    
    /// Indicates whether the assistant is currently speaking
    @Published var isSpeaking: Bool = false
    
    /// Indicates whether TTS is muted
    @Published var isMuted: Bool = false
    
    // MARK: - Private Properties
    
    /// The speech recognizer instance. We'll specify the locale for US English.
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    
    /// The recognition request that handles the audio buffer.
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    /// The recognition task that manages the ongoing recognition process.
    private var recognitionTask: SFSpeechRecognitionTask?
    
    /// The audio engine to process audio input from the microphone.
    private var audioEngine = AVAudioEngine()
    
    /// Text-to-Speech synthesizer
    private var speechSynthesizer = AVSpeechSynthesizer()
    
    /// Buffer for streaming text
    private var streamingBuffer: String = ""
    private var lastSpokenLength: Int = 0
    private var streamingTimer: Timer?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        // Set up TTS delegate
        speechSynthesizer.delegate = self
        // Request permissions as soon as the manager is created.
        requestPermissions()
    }
    
    // MARK: - Public Methods
    
    /// Requests authorization for speech recognition and microphone access.
    func requestPermissions() {
        // Request speech recognition authorization
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                self.speechRecognitionAuthorized = (authStatus == .authorized)
            }
            if authStatus != .authorized {
                print("Speech recognition not authorized.")
            }
        }
        
        // Request microphone access
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.microphoneAuthorized = granted
            }
            if !granted {
                print("Microphone access was denied.")
            }
        }
    }
    
    /// Speaks the given text using Text-to-Speech
    func speak(_ text: String, settings: AppSettings? = nil) {
        // Check if muted
        if isMuted {
            print("🔊 TTS: Muted, not speaking")
            return
        }
        
        print("🔊 TTS: Starting to speak: '\(text)'")
        
        // Stop any current speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        // Configure audio session for playback - Enhanced for better TTS
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use playAndRecord with proper options for TTS
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true)
            print("🔊 TTS: Audio session configured successfully for playAndRecord with spokenAudio mode")
        } catch {
            print("🔊 TTS: Failed to set up audio session: \(error)")
            // Try simpler fallback configuration
            do {
                try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.defaultToSpeaker])
                try audioSession.setActive(true)
                print("🔊 TTS: Fallback audio session configured with playback only")
            } catch {
                print("🔊 TTS: Fallback audio session failed: \(error)")
                return
            }
        }
        
        // Create speech utterance
        let utterance = AVSpeechUtterance(string: text)
        
        // Apply settings if provided, with better voice selection
        if let settings = settings {
            // Try to find the preferred voice
            if let voice = AVSpeechSynthesisVoice(language: settings.preferredVoice) {
                utterance.voice = voice
                print("🔊 TTS: Using preferred voice: \(voice.name)")
            } else {
                // Fallback to high quality English voice
                let englishVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
                let preferredVoice = englishVoices.first { $0.quality == .enhanced || $0.quality == .premium } ?? 
                                   AVSpeechSynthesisVoice(language: "en-US")
                utterance.voice = preferredVoice
                print("🔊 TTS: Using fallback voice: \(preferredVoice?.name ?? "default")")
            }
            
            // Apply speed and pitch settings with more natural ranges
            utterance.rate = Float(max(0.4, min(0.7, settings.voiceSpeed))) // More natural speed range
            utterance.pitchMultiplier = Float(max(0.8, min(1.3, settings.voicePitch))) // More natural pitch range
            print("🔊 TTS: Voice settings - Speed: \(utterance.rate), Pitch: \(utterance.pitchMultiplier)")
        } else {
            // Default settings with high quality voice
            let englishVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
            let defaultVoice = englishVoices.first { $0.quality == .enhanced || $0.quality == .premium } ?? 
                              AVSpeechSynthesisVoice(language: "en-US")
            utterance.voice = defaultVoice
            utterance.rate = 0.55 // Slightly faster than default for more natural speech
            utterance.pitchMultiplier = 1.0
            print("🔊 TTS: Using default high-quality voice: \(defaultVoice?.name ?? "system default")")
        }
        
        utterance.volume = 1.0 // Maximum volume for better audibility
        utterance.preUtteranceDelay = 0.1 // Small delay before speaking
        
        // Start speaking
        print("🔊 TTS: Starting synthesis...")
        isSpeaking = true
        speechSynthesizer.speak(utterance)
    }
    
    /// Stops current speech
    func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }
        stopStreamingTTS()
    }
    
    /// Toggles mute state
    func toggleMute() {
        isMuted.toggle()
        if isMuted && speechSynthesizer.isSpeaking {
            stopSpeaking()
        }
        print("🔊 TTS: Mute toggled to \(isMuted)")
    }
    
    /// Starts streaming TTS - speaks text as it's being generated
    func startStreamingTTS(settings: AppSettings? = nil) {
        guard !isMuted else { return }
        
        print("🔊 TTS: Starting streaming mode")
        streamingBuffer = ""
        lastSpokenLength = 0
        
        // Configure audio session once for streaming
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("🔊 TTS: Failed to configure audio session for streaming: \(error)")
        }
    }
    
    /// Updates streaming text and speaks new content
    func updateStreamingText(_ text: String, settings: AppSettings? = nil) {
        guard !isMuted else { return }
        
        streamingBuffer = text
        
        // Don't interrupt if we're already speaking the current chunk
        guard !speechSynthesizer.isSpeaking else { return }
        
        // Check if we have enough new content to speak (at least a sentence)
        let newContent = String(text.dropFirst(lastSpokenLength))
        
        // Look for sentence endings or enough content
        if newContent.contains(".") || newContent.contains("!") || newContent.contains("?") || newContent.count > 20 {
            speakNewContent(settings: settings)
        }
    }
    
    /// Stops streaming TTS
    func stopStreamingTTS() {
        streamingTimer?.invalidate()
        streamingTimer = nil
        streamingBuffer = ""
        lastSpokenLength = 0
        print("🔊 TTS: Streaming stopped")
    }
    
    /// Cleans up streaming state without stopping ongoing speech
    func cleanupStreamingState() {
        streamingTimer?.invalidate()
        streamingTimer = nil
        streamingBuffer = ""
        lastSpokenLength = 0
        print("🔊 TTS: Streaming state cleaned up, speech continues")
    }
    
    /// Finishes streaming TTS by speaking any remaining content
    func finishStreamingTTS(finalText: String, settings: AppSettings? = nil) {
        guard !isMuted else {
            cleanupStreamingState()
            return
        }
        
        // Check if there's any remaining content that hasn't been spoken
        let remainingContent = String(finalText.dropFirst(lastSpokenLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !remainingContent.isEmpty && remainingContent.count > 1 {
            print("🔊 TTS: Speaking remaining content: '\(remainingContent)'")
            
            // Wait for current speech to finish before speaking remaining content
            if speechSynthesizer.isSpeaking {
                // Queue the remaining content to be spoken after current speech finishes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.speakRemainingContent(remainingContent, settings: settings)
                }
            } else {
                speakRemainingContent(remainingContent, settings: settings)
            }
        } else {
            print("🔊 TTS: No remaining content to speak")
            cleanupStreamingState()
        }
    }
    
    private func speakRemainingContent(_ content: String, settings: AppSettings? = nil) {
        // Create utterance for remaining content
        let utterance = AVSpeechUtterance(string: content)
        
        // Apply settings
        if let settings = settings {
            if let voice = AVSpeechSynthesisVoice(language: settings.preferredVoice) {
                utterance.voice = voice
            } else {
                let englishVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
                let preferredVoice = englishVoices.first { $0.quality == .enhanced || $0.quality == .premium } ?? 
                                   AVSpeechSynthesisVoice(language: "en-US")
                utterance.voice = preferredVoice
            }
            utterance.rate = Float(max(0.4, min(0.7, settings.voiceSpeed))) // More natural speed range
            utterance.pitchMultiplier = Float(max(0.8, min(1.3, settings.voicePitch))) // More natural pitch range
        } else {
            let englishVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
            let defaultVoice = englishVoices.first { $0.quality == .enhanced || $0.quality == .premium } ?? 
                              AVSpeechSynthesisVoice(language: "en-US")
            utterance.voice = defaultVoice
            utterance.rate = 0.55 // Slightly faster than default for more natural speech
            utterance.pitchMultiplier = 1.0
        }
        
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.0
        
        isSpeaking = true
        speechSynthesizer.speak(utterance)
        
        // Clean up streaming state after queuing the final speech
        cleanupStreamingState()
    }
    
    private func speakNewContent(settings: AppSettings? = nil) {
        let newContent = String(streamingBuffer.dropFirst(lastSpokenLength)).trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !newContent.isEmpty && newContent.count > 3 else { return }
        
        print("🔊 TTS: Speaking new content: '\(newContent)'")
        
        // Create utterance for new content
        let utterance = AVSpeechUtterance(string: newContent)
        
        // Apply settings
        if let settings = settings {
            if let voice = AVSpeechSynthesisVoice(language: settings.preferredVoice) {
                utterance.voice = voice
            } else {
                let englishVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
                let preferredVoice = englishVoices.first { $0.quality == .enhanced || $0.quality == .premium } ?? 
                                   AVSpeechSynthesisVoice(language: "en-US")
                utterance.voice = preferredVoice
            }
            utterance.rate = Float(max(0.4, min(0.7, settings.voiceSpeed))) // More natural speed range
            utterance.pitchMultiplier = Float(max(0.8, min(1.3, settings.voicePitch))) // More natural pitch range
        } else {
            let englishVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
            let defaultVoice = englishVoices.first { $0.quality == .enhanced || $0.quality == .premium } ?? 
                              AVSpeechSynthesisVoice(language: "en-US")
            utterance.voice = defaultVoice
            utterance.rate = 0.55 // Slightly faster than default for more natural speech
            utterance.pitchMultiplier = 1.0
        }
        
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.0 // No delay for streaming
        
        isSpeaking = true
        speechSynthesizer.speak(utterance)
        
        // Update the last spoken length
        lastSpokenLength = streamingBuffer.count
    }
    
    /// Starts the speech recognition process.
    func startTranscription() {
        // Clear any previous state
        transcribedText = ""
        isTranscriptionFinal = false
        error = nil
        
        print("🎤 Starting speech transcription...")
        
        // --- 1. Check permissions ---
        guard SFSpeechRecognizer.authorizationStatus() == .authorized, AVAudioApplication.shared.recordPermission == .granted else {
            print("🎤 Permissions not granted. Please enable Speech Recognition and Microphone access in Settings.")
            return
        }
        
        // Stop any existing recognition task
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        // Stop audio engine if running
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // --- 2. Set up the audio session ---
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use playAndRecord to allow both recording and TTS playback
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("🎤 Audio session configured for recording")
        } catch {
            self.error = error
            print("🎤 Failed to configure audio session: \(error)")
            return
        }
        
        // --- 3. Create the recognition request ---
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object")
        }
        
        // --- 4. Create and start the recognition task ---
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                // Update the transcribed text with the latest result
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    print("🎤 Transcribed: '\(self.transcribedText)'")
                }
                isFinal = result.isFinal
                
                if isFinal {
                    print("🎤 Transcription marked as final")
                }
            }
            
            if let error = error {
                print("🎤 Recognition error: \(error)")
                DispatchQueue.main.async {
                    self.error = error
                    self.stopTranscription()
                }
            } else if isFinal {
                // If transcription is final, stop everything
                print("🎤 Transcription final, stopping...")
                DispatchQueue.main.async {
                    self.stopTranscription()
                }
            }
        }
        
        // --- 5. Set up the audio engine and start recording ---
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            self.error = error
            stopTranscription()
        }
    }
    
    /// Stops the speech recognition process.
    func stopTranscription() {
        // Stop the audio engine and remove the tap
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionTask?.finish() // Use finish() for final result, cancel() to discard.
        
        recognitionRequest = nil
        recognitionTask = nil
        
        // Don't deactivate audio session - keep it active for TTS
        // This allows seamless voice recognition -> TTS workflow
        print("🎤 Speech recognition stopped, keeping audio session active")
        
        // Set the flag to indicate we are done.
        DispatchQueue.main.async {
            self.isTranscriptionFinal = true
        }
    }
} 

// MARK: - AVSpeechSynthesizerDelegate
extension SpeechManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔊 TTS: Speech started")
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🔊 TTS: Speech finished")
        DispatchQueue.main.async {
            // Only set to false if no more utterances are queued
            if !synthesizer.isSpeaking {
                self.isSpeaking = false
                print("🔊 TTS: All speech finished")
            } else {
                print("🔊 TTS: Utterance finished, more queued")
            }
        }
        
        // Don't deactivate audio session - let the app manage it
        // This prevents interference with voice recognition
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🔊 TTS: Speech cancelled")
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.stopStreamingTTS()
        }
    }
} 
