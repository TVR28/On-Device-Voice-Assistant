# Product Requirements Document: On-Device Voice Assistant

## 1. Introduction/Overview

This document outlines the requirements for a personal voice assistant iOS application that operates entirely on-device. The primary motivation is to provide a private, accessible, and accurate alternative to existing voice assistants. Users will interact with the assistant via voice, receive a spoken response, and have their conversations saved locally. The assistant's personality will be knowledgeable, friendly, and honest, with options for user customization.

## 2. Goals

*   **Privacy:** Ensure all user data, including conversations and queries, is processed and stored locally on the user's device, never leaving it.
*   **Performance:** Deliver a responsive user experience with low latency between the user's query and the assistant's audio response.
*   **Accuracy:** Achieve high accuracy in understanding user speech (STT), providing relevant and correct information (LLM), and generating a natural-sounding voice (TTS).
*   **User Experience:** Provide a clean, intuitive, and high-quality user interface comparable to leading applications like ChatGPT and Perplexity.
*   **On-Device Functionality:** All core components (STT, LLM, TTS) must run efficiently on an iPhone 15 Pro without relying on cloud services.

## 3. User Stories

*   **As a user,** I want to tap a button to start speaking my question so that I can interact with the assistant hands-free.
*   **As a user,** I want the assistant to listen to my question and provide a spoken answer so I can have a natural, voice-based conversation.
*   **As a user,** I want all my interactions to be processed on my phone so that my privacy is fully protected.
*   **As a user,** I want to see a text transcript of my past conversations so I can refer back to them later.
*   **As a user,** I want to be able to delete specific chats or my entire chat history so that I have full control over my data.
*   **As a user,** I want to mark important conversations as 'favorites' so I can find them easily in the future.
*   **As a user,** I want to modify the assistant's instructions or personality via a system prompt so I can customize its behavior to my liking.

## 4. Functional Requirements

1.  **Voice Input:** The app must feature a microphone toggle button to start and stop audio recording.
2.  **On-Device STT:** The app must convert the user's spoken words into text directly on the device.
3.  **On-Device LLM:** The app must use an on-device Large Language Model to understand the transcribed text and generate a relevant response.
4.  **On-Device TTS:** The app must convert the generated text response into natural-sounding speech on the device.
5.  **Conversation History:** The app must display the conversation history in a clear, text-based chat format.
6.  **Local Storage:**
    *   All conversation history must be stored locally on the device.
    *   History older than 30 days must be automatically deleted.
7.  **History Management:** Users must have the ability to:
    *   Delete individual chat messages.
    *   Mark specific chats as favorites.
8.  **Personality Customization:** The app must provide a settings screen where the user can input a custom system prompt to define the assistant's personality and instructions.
9.  **Default Personality:** The default assistant personality shall be knowledgeable, friendly, polite, and honest. If it does not know an answer, it must state that it does not know.
10. **Error Handling:**
    *   If the STT model fails to understand the user, the assistant must respond with: "I'm sorry, I didn't catch that."
    *   Technical failures within the application should be handled gracefully as exceptions.

## 5. Non-Goals (Out of Scope for V1)

*   Any form of cloud-based processing.
*   Text-based or image-based (multi-modal) input.
*   Proactive assistance where the assistant initiates conversations.
*   Integration with other apps or system-level services (e.g., setting alarms, sending messages, controlling smart home devices).

## 6. Design Considerations

*   The UI should be clean, modern, and minimalist, inspired by ChatGPT and Perplexity.
*   A single, prominent microphone button should be the primary call-to-action on the main screen.
*   The app must provide clear visual feedback to the user, indicating its state (e.g., listening, processing, speaking).
*   The conversation view should be styled for maximum readability, clearly distinguishing between user queries and assistant responses.

## 7. Technical Considerations

*   All models (STT, LLM, TTS) must be selected or optimized for high performance on the Apple A17 Pro chip (iPhone 15 Pro).
*   Apple's Core ML framework should be the primary tool for deploying and managing on-device models.
*   Local data storage can be implemented using SwiftData or Core Data for persistence.
*   Research is required to select the optimal on-device models that balance performance and capability (e.g., quantized open-source LLMs, Apple's built-in TTS).

## 8. Success Metrics

*   **Latency:** End-to-end response time (from user finishing speaking to assistant starting to speak) is consistently under 3 seconds.
*   **Accuracy:**
    *   High user satisfaction with the relevance and correctness of the assistant's answers.
    *   Low Word Error Rate (WER) for the speech-to-text transcription.
*   **Performance:** Minimal battery drain and efficient CPU/memory usage during operation.
*   **Voice Quality:** The TTS voice is rated as "natural" and "pleasant" by users.
*   **UI/UX:** High ratings for UI intuitiveness and overall user experience.

## 9. Open Questions

*   Which specific on-device models for STT, LLM, and TTS offer the best balance of performance, accuracy, and resource consumption on an iPhone 15 Pro?
*   What is the acceptable trade-off between model size/capability and on-device performance (latency, battery impact)?
*   What is the most efficient implementation for the 30-day automatic chat history deletion? 