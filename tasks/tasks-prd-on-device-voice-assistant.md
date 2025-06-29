## Task List for On-Device Voice Assistant (Beginner Focused)

**Note for the Developer:** Hello! This task list is designed for someone new to iOS development. We will build this app together, step-by-step. Each task includes extra details and "Discussion Points" where we should pause and decide on the implementation together. Don't hesitate to ask questions at any point!

## Relevant Files

- `VoiceFoundationApp/VoiceFoundationApp/ContentView.swift` - The main view for user interaction.
- `VoiceFoundationApp/VoiceFoundationAppTests/ContentViewTests.swift` - UI tests for `ContentView`.
- `VoiceFoundationApp/VoiceFoundationApp/ConversationHistoryView.swift` - (New File) A view to display the list of past conversations.
- `VoiceFoundationApp/VoiceFoundationApp/SettingsView.swift` - (New File) A view for managing settings.
- `VoiceFoundationApp/VoiceFoundationApp/SpeechManager.swift` - (New File) A helper class for Speech-to-Text (STT).
- `VoiceFoundationApp/VoiceFoundationApp/ModelManager.swift` - (New File) A helper class to manage the on-device LLM.
- `VoiceFoundationApp/VoiceFoundationApp/TTSManager.swift` - (New File) A helper class for Text-to-Speech (TTS).
- `VoiceFoundationApp/VoiceFoundationApp/PersistenceController.swift` - (New File) A helper to manage the local database.

---

## Tasks

- [x] **1.0 Project Setup and UI Scaffolding**
  - [x] 1.1 Implement the main `ContentView.swift`. **Beginner's Note:** We'll use SwiftUI elements like `VStack`, `Button`, and `Image(systemName: "mic.fill")` to create a simple layout with a microphone button.
  - [x] 1.2 Add visual state indicators. **Beginner's Note:** We'll create a Swift `enum` to represent states like `idle`, `listening`, `thinking`. A `@State` variable in `ContentView` will hold the current state and the UI will change based on its value (e.g., text label, button color).
  - [x] 1.3 Set up basic navigation. **Beginner's Note:** We'll use a `NavigationStack` in our main view. We'll add `NavigationLink`s, probably with icon buttons, to navigate to the (currently empty) `ConversationHistoryView` and `SettingsView`.

- [x] **2.0 On-Device Speech-to-Text (STT) Integration**
  - [x] **Discussion Point:** Before we start this section, let's discuss how the `SpeechManager` will communicate with the `ContentView`. We'll likely use the "ObservableObject" pattern, which is a modern SwiftUI way to handle this.
  - [x] 2.1 Create the `SpeechManager.swift` class. **Beginner's Note:** In Xcode, go to **File > New > File...**, choose **Swift File**, and name it `SpeechManager`.
  - [x] 2.2 Request user permissions. **Important:** We must add keys to the `Info.plist` file. Go to `Info.plist` in Xcode, and add two new rows: `Privacy - Speech Recognition Usage Description` and `Privacy - Microphone Usage Description`, providing a sentence for each explaining why we need access.
  - [x] 2.3 Implement the permission request logic in `SpeechManager` by calling `SFSpeechRecognizer.requestAuthorization` and `AVAudioSession.sharedInstance().requestRecordPermission`.
  - [x] 2.4 Integrate Apple's `Speech` framework in `SpeechManager` to handle starting/stopping audio recording and transcription. **Beginner's Note:** Remember to `import Speech` and `import AVFoundation`.
  - [x] 2.5 Connect `SpeechManager` to the `ContentView` to update the UI state (e.g., show "listening...").
  - [x] 2.6 Implement error handling for cases like permission denial. We should show an `Alert` to the user if permissions are not granted.

- [ ] **3.0 On-Device LLM and TTS Integration**
  - [ ] **3.1 Discussion Point: Select and Prepare the LLM.** This is our most important research step.
      - 3.1.1 We need to find a small, efficient LLM that runs well on an iPhone (e.g., a quantized version of Phi-3, Gemma, or a similar model).
      - 3.1.2 We will then use a Python script with `coremltools` to convert this model into the Core ML format. I will guide you through setting this up.
      - 3.1.3 Once we have the `.mlmodelc` file, we'll just drag and drop it into our Xcode project.
  - [ ] 3.2 Create the `ModelManager.swift` class to run the Core ML model. **Beginner's Note:** When you add the model to Xcode, it auto-generates a Swift class for it. Our `ModelManager` will use this generated class to make predictions.
  - [ ] 3.3 Create the `TTSManager.swift` class and integrate `AVSpeechSynthesizer` to convert text into speech. **Beginner's Note:** This is a straightforward Apple API. We'll use it to speak the LLM's response. Remember to `import AVFoundation`.
  - [ ] 3.4 Wire everything together. The flow will be: `SpeechManager` (transcribes text) -> `ModelManager` (generates response) -> `TTSManager` (speaks response).
  - [ ] 3.5 Implement the "I'm sorry, I didn't catch that" fallback response.

- [ ] **4.0 Conversation History and Local Storage**
  - [ ] **4.1 Discussion Point: Data Persistence.** We'll use SwiftData, Apple's newest framework for local storage.
      - 4.1.1 Create `PersistenceController.swift` to manage the SwiftData setup.
      - 4.1.2 Define a `ChatMessage` class using the `@Model` macro to define its schema (ID, text, sender, timestamp, isFavorite).
  - [ ] 4.2 Create `ConversationHistoryView.swift` to display messages. **Beginner's Note:** We'll use a `@Query` to fetch the saved `ChatMessage` objects from SwiftData and show them in a `List`.
  - [ ] 4.3 Implement logic to save each user query and assistant response to the database after every interaction.
  - [ ] 4.4 Add swipe-to-delete functionality. **Beginner's Note:** This is a standard SwiftUI feature. We can use the `.onDelete(perform:)` modifier on the `ForEach` inside our `List`.
  - [ ] 4.5 Implement a "favorite" button or gesture for each message.
  - [ ] 4.6 Implement a function to automatically delete messages older than 30 days. We can call this function from our `PersistenceController` every time the app starts.

- [ ] **5.0 Settings and Personality Customization**
  - [ ] 5.1 Create the `SettingsView.swift` UI.
  - [ ] 5.2 Add a `TextEditor` in `SettingsView` for the user to type their custom system prompt.
  - [ ] 5.3 Save the custom prompt to `UserDefaults`. **Beginner's Note:** `UserDefaults` is a simple key-value store built into iOS, perfect for saving settings like this.
  - [ ] 5.4 Update `ModelManager` to check `UserDefaults` for a custom prompt. If one exists, it will be prepended to the user's query before being sent to the LLM.

### Notes

- Unit tests should be created for business logic within managers and controllers.
- UI tests should verify the behavior and state changes of the views.
- Use `CMD+U` in Xcode to run all tests.

## Relevant Files

- `VoiceFoundationApp/VoiceFoundationApp/ContentView.swift` - The main view for user interaction, including the microphone button and state indicators.
- `VoiceFoundationApp/VoiceFoundationAppTests/ContentViewTests.swift` - UI tests for `ContentView`.
- `VoiceFoundationApp/VoiceFoundationApp/ConversationHistoryView.swift` - (New File) A view to display the list of past conversations.
- `VoiceFoundationApp/VoiceFoundationApp/SettingsView.swift` - (New File) A view for managing settings and customizing the assistant's personality.
- `VoiceFoundationApp/VoiceFoundationApp/SpeechManager.swift` - (New File) A helper class to encapsulate the logic for the Speech-to-Text (STT) integration using Apple's `Speech` framework.
- `VoiceFoundationApp/VoiceFoundationAppTests/SpeechManagerTests.swift` - (New File) Unit tests for the `SpeechManager`.
- `VoiceFoundationApp/VoiceFoundationApp/ModelManager.swift` - (New File) A helper class to load and manage the on-device Core ML model (LLM).
- `VoiceFoundationApp/VoiceFoundationAppTests/ModelManagerTests.swift` - (New File) Unit tests for the `ModelManager`.
- `VoiceFoundationApp/VoiceFoundationApp/TTSManager.swift` - (New File) A helper class to handle Text-to-Speech (TTS) functionality using `AVSpeechSynthesizer`.
- `VoiceFoundationApp/VoiceFoundationApp/PersistenceController.swift` - (New File) A helper to manage the Core Data or SwiftData stack for storing conversation history.
- `VoiceFoundationApp/VoiceFoundationAppTests/PersistenceControllerTests.swift` - (New File) Unit tests for the persistence logic. 