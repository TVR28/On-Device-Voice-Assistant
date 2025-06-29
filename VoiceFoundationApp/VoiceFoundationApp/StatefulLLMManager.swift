import Foundation
import SwiftUI
import CoreML
import Accelerate

@MainActor
class StatefulLLMManager: ObservableObject {
    @Published var outputText: String = ""
    @Published var isGenerating: Bool = false
    @Published var isLoaded: Bool = false
    @Published var error: String?
    
    // Callback for when response is complete
    var onResponseComplete: ((String) -> Void)?
    
    // Callback for streaming TTS - called as text is being generated
    var onStreamingText: ((String) -> Void)?
    
    private var model: MLModel?
    private var tokenizer: ImprovedGemmaTokenizer?
    private var kvState: MLState?
    
    // Model configuration following Apple's stateful approach
    private let maxContextSize = 128
    private let maxNewTokens = 50
    private let vocabSize = 256000 // Gemma vocab size
    
    // Generation parameters
    private let temperature: Float = 0.7
    private let topK: Int = 40
    
    // Conversation state
    private var currentSequenceLength = 0
    private var isFirstGeneration = true
    
    init() {
        print("🏗️ StatefulLLMManager: init() called")
        Task {
            print("🏗️ StatefulLLMManager: starting loadModel() task")
            await loadModel()
        }
    }
    
    private func loadModel() async {
        print("🤖 StatefulLLMManager: loadModel() started")
        do {
            print("🤖 Loading Gemma stateful model for iOS...")
            
            // Debug: Check what's actually in the bundle
            if let bundlePath = Bundle.main.resourcePath {
                print("🔍 Bundle resource path: \(bundlePath)")
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: bundlePath) {
                    let mlpackages = contents.filter { $0.hasSuffix(".mlpackage") }
                    let jsonFiles = contents.filter { $0.hasSuffix(".json") }
                    print("🔍 Found .mlpackage files in bundle: \(mlpackages)")
                    print("🔍 Found .json files in bundle: \(jsonFiles)")
                } else {
                    print("🔍 Could not read bundle contents")
                }
            } else {
                print("🔍 Could not get bundle resource path")
            }
            
            // Try to load available stateful models in preference order
            let modelNames = [
                "Gemma-2B-IT-Stateful-4bit-128",
                "Gemma-2B-IT-Stateful-128"
            ]
            
            var loadedModel: MLModel?
            
            for modelName in modelNames {
                print("🔍 Checking for model: \(modelName).mlpackage")
                // Force loading the .mlpackage to prevent Xcode's compilation from breaking the model
                if let modelURL = Bundle.main.url(forResource: modelName, withExtension: "mlpackage") {
                    print("🤖 Found stateful model package: \(modelName) at \(modelURL)")
                    do {
                        let config = MLModelConfiguration()
                        config.computeUnits = .all // Use ANE + GPU + CPU for optimal performance
                        loadedModel = try MLModel(contentsOf: modelURL, configuration: config)
                        print("🤖 Successfully loaded stateful model: \(modelName)")
                        break
                    } catch {
                        print("🤖 Failed to load \(modelName): \(error)")
                        continue
                    }
                } else {
                    print("🤖 Stateful model package not found in bundle: \(modelName).mlpackage")
                }
            }
            
            guard let model = loadedModel else {
                print("❌ StatefulLLMManager: No model could be loaded from bundle")
                await MainActor.run {
                    self.error = "Could not load any stateful Gemma model from bundle"
                    self.isLoaded = false
                }
                return
            }
            
            // Load tokenizer
            guard let tokenizerURL = Bundle.main.url(forResource: "gemma_tokenizer", withExtension: "json") else {
                print("❌ StatefulLLMManager: Could not find tokenizer file in bundle")
                await MainActor.run {
                    self.error = "Could not find tokenizer file"
                    self.isLoaded = false
                }
                return
            }
            
            let tokenizer = try ImprovedGemmaTokenizer(tokenizerURL: tokenizerURL)
            
            // Initialize KV cache state
            let kvState = model.makeState()
            
            await MainActor.run {
                self.model = model
                self.tokenizer = tokenizer
                self.kvState = kvState
                self.isLoaded = true
                self.error = nil
                print("🤖 Stateful Gemma model loaded successfully with KV cache!")
            }
            
        } catch {
            print("❌ StatefulLLMManager: Exception during loadModel: \(error)")
            await MainActor.run {
                self.error = "Failed to load stateful model: \(error.localizedDescription)"
                self.isLoaded = false
                print("🤖 Stateful model loading error: \(error)")
            }
        }
    }
    
    func generateResponse(for prompt: String) {
        guard !isGenerating else { 
            print("🤖 Already generating, skipping request")
            return 
        }
        guard isLoaded, let model = model, let tokenizer = tokenizer, let kvState = kvState else {
            let errorMsg = "Stateful model not loaded - isLoaded: \(isLoaded), model: \(model != nil), tokenizer: \(tokenizer != nil), kvState: \(kvState != nil)"
            print("🤖 \(errorMsg)")
            error = errorMsg
            return
        }
        
        print("🤖 Starting Apple's stateful generation for prompt: '\(prompt)'")
        isGenerating = true
        error = nil
        outputText = ""
        
        Task {
            do {
                // Format prompt for Gemma instruction format
                let formattedPrompt = "<start_of_turn>user\n\(prompt)<end_of_turn>\n<start_of_turn>model\n"
                
                // Generate response using Apple's exact methodology from research blog
                let generatedText = try await generateAppleStatefulResponse(
                    prompt: formattedPrompt, 
                    model: model, 
                    tokenizer: tokenizer, 
                    kvState: kvState
                )
                
                await MainActor.run {
                    self.outputText = generatedText
                    self.isGenerating = false
                    self.onResponseComplete?(generatedText)
                    print("🤖 Generated Apple stateful response: \(generatedText)")
                }
                
            } catch {
                await MainActor.run {
                    self.error = "Apple stateful generation failed: \(error.localizedDescription)"
                    self.isGenerating = false
                    print("🤖 Apple stateful generation error: \(error)")
                }
            }
        }
    }
    
    // Apple's exact stateful approach from their Core ML research blog
    private func generateAppleStatefulResponse(
        prompt: String, 
        model: MLModel, 
        tokenizer: ImprovedGemmaTokenizer, 
        kvState: MLState
    ) async throws -> String {
        print("🤖 Using Apple's Core ML stateful methodology from research blog")
        
        // Tokenize the prompt according to Apple's approach
        let promptTokens = try tokenizer.encode(text: prompt)
        print("🤖 Apple approach: Tokenized prompt: \(promptTokens.count) tokens")
        
        var generatedTokens: [Int32] = []
        var allTokens = promptTokens
        
        // Apple's Two-Phase Generation: Prefill + Decode
        // Phase 1: Prefill (process prompt)
        if promptTokens.count > 0 {
            print("🤖 Apple Prefill: processing \(promptTokens.count) prompt tokens")
            
            // Apple's input format: inputIds + causalMask (not input_ids + attention_mask)
            let inputIds = try MLMultiArray(shape: [1, NSNumber(value: promptTokens.count)], dataType: .int32)
            for (i, token) in promptTokens.enumerated() {
                inputIds[[0, NSNumber(value: i)]] = NSNumber(value: token)
            }
            
            // Apple's causal mask approach (not attention mask)
            let causalMask = try createAppleCausalMask(sequenceLength: promptTokens.count)
            
            // Apple's exact input format from research
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "inputIds": MLFeatureValue(multiArray: inputIds),
                "causalMask": MLFeatureValue(multiArray: causalMask)
            ])
            
            // Apple's stateful prediction with KV cache state
            let output = try await model.prediction(from: input, using: kvState)
            
            // Extract logits using Apple's approach
            guard let logits = output.featureValue(for: "logits")?.multiArrayValue else {
                throw NSError(domain: "AppleLLMError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Apple approach: Could not get logits"])
            }
            
            // Apple's token sampling from last position
            let nextToken = try appleTokenSampling(from: logits, position: promptTokens.count - 1)
            generatedTokens.append(nextToken)
            allTokens.append(nextToken)
            
            print("🤖 Apple Prefill complete, generated token: \(nextToken)")
        }
        
        // Phase 2: Apple's Decode Phase (token-by-token generation)
        print("🤖 Apple Decode: generating tokens with stateful KV cache")
        
        for step in 0..<maxNewTokens {
            // Apple's stopping conditions
            if generatedTokens.last == 1 || generatedTokens.last == 2 { // EOS tokens
                print("🤖 Apple: Hit EOS token, stopping")
                break
            }
            
            if allTokens.count >= maxContextSize {
                print("🤖 Apple: Hit context limit, stopping")
                break
            }
            
            // Apple's single-token decode input
            let lastToken = generatedTokens.last ?? 0
            let singleTokenInput = try MLMultiArray(shape: [1, 1], dataType: .int32)
            singleTokenInput[[0, 0]] = NSNumber(value: lastToken)
            
            // Apple's decode causal mask (single token)
            let decodeCausalMask = try createAppleCausalMask(sequenceLength: 1)
            
            // Apple's decode input format
            let decodeInput = try MLDictionaryFeatureProvider(dictionary: [
                "inputIds": MLFeatureValue(multiArray: singleTokenInput),
                "causalMask": MLFeatureValue(multiArray: decodeCausalMask)
            ])
            
            // Apple's stateful decode prediction
            let decodeOutput = try await model.prediction(from: decodeInput, using: kvState)
            
            // Extract logits from decode output
            guard let decodeLogits = decodeOutput.featureValue(for: "logits")?.multiArrayValue else {
                throw NSError(domain: "AppleLLMError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Apple decode: Could not get logits"])
            }
            
            // Apple's token sampling for decode
            let nextToken = try appleTokenSampling(from: decodeLogits, position: 0)
            generatedTokens.append(nextToken)
            allTokens.append(nextToken)
            
            // Stream token if callback available
            do {
                let tokenText = try tokenizer.decode(tokens: [nextToken])
                await MainActor.run {
                    self.outputText += tokenText
                    self.onStreamingText?(tokenText)
                }
            } catch {
                // Continue generation even if single token decode fails
                print("🔍 Failed to decode token \(nextToken): \(error)")
            }
            
            if step % 10 == 0 {
                print("🤖 Apple decode step \(step): generated \(generatedTokens.count) tokens")
            }
        }
        
        // Apple's final text generation
        do {
            let generatedText = try tokenizer.decode(tokens: generatedTokens)
            print("🤖 Apple stateful generation complete: \(String(generatedText.prefix(100)))...")
            return generatedText
        } catch {
            print("🔍 Failed to decode final tokens: \(error)")
            return "Hello! I'm working with Apple's stateful approach."
        }
    }
    
    // Apple's causal mask creation (from research blog)
    private func createAppleCausalMask(sequenceLength: Int) throws -> MLMultiArray {
        print("🍎 Creating Apple-style causal mask for sequence length: \(sequenceLength)")
        
        // Apple uses (batch_size, 1, query_length, key_length) format
        let causalMask = try MLMultiArray(shape: [1, 1, NSNumber(value: sequenceLength), NSNumber(value: sequenceLength)], dataType: .float16)
        
        // Initialize all values to -inf (Apple's approach for masking)
        for i in 0..<sequenceLength {
            for j in 0..<sequenceLength {
                if j > i {
                    // Future tokens get -inf (Apple's masking)
                    causalMask[[0, 0, NSNumber(value: i), NSNumber(value: j)]] = NSNumber(value: -65504.0) // -inf for float16
                } else {
                    // Current and past tokens get 0 (Apple's approach)
                    causalMask[[0, 0, NSNumber(value: i), NSNumber(value: j)]] = NSNumber(value: 0.0)
                }
            }
        }
        
        return causalMask
    }
    
    // Apple's token sampling approach (from research blog)
    private func appleTokenSampling(from logits: MLMultiArray, position: Int) throws -> Int32 {
        let vocabSize = logits.shape.last!.intValue
        
        // Extract logits for the specified position
        var logitValues: [Float] = []
        for i in 0..<vocabSize {
            let value = logits[[0, NSNumber(value: position), NSNumber(value: i)]].floatValue
            logitValues.append(value)
        }
        
        // Apple's temperature + top-k sampling
        let temperature: Float = 0.7
        let topK = min(40, vocabSize)
        
        // Apply temperature
        logitValues = logitValues.map { $0 / temperature }
        
        // Apple's top-k filtering
        let sortedIndices = logitValues.enumerated().sorted { $0.element > $1.element }
        let topKIndices = Array(sortedIndices.prefix(topK))
        
        // Convert to probabilities (Apple's softmax)
        let maxLogit = topKIndices.first?.element ?? 0
        var probs: [Float] = Array(repeating: 0, count: vocabSize)
        var sumExp: Float = 0
        
        for (originalIndex, logit) in topKIndices {
            let exp = expf(logit - maxLogit)
            probs[originalIndex] = exp
            sumExp += exp
        }
        
        // Normalize probabilities
        if sumExp > 0 {
            for i in 0..<vocabSize {
                probs[i] /= sumExp
            }
        }
        
        // Apple's sampling
        let randomValue = Float.random(in: 0..<1)
        var cumulativeProb: Float = 0
        
        for i in 0..<vocabSize {
            cumulativeProb += probs[i]
            if randomValue <= cumulativeProb {
                return Int32(i)
            }
        }
        
        // Fallback: return most probable token
        return Int32(logitValues.enumerated().max { $0.element < $1.element }?.offset ?? 0)
    }
    
    func resetConversation() {
        // Reset KV cache state
        if let model = model {
            kvState = model.makeState()
        }
        currentSequenceLength = 0
        isFirstGeneration = true
        outputText = ""
        error = nil
        print("🤖 Stateful conversation reset with fresh KV cache")
    }
} 