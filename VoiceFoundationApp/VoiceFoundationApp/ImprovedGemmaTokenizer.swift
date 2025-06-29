import Foundation

class ImprovedGemmaTokenizer {
    private let vocabSize = 256000
    private let padTokenId: Int32 = 0
    private let eosTokenId: Int32 = 1
    private let bosTokenId: Int32 = 2
    private let unkTokenId: Int32 = 3
    
    // Special tokens for Gemma instruction format
    private let startOfTurnUser = "<start_of_turn>user"
    private let startOfTurnModel = "<start_of_turn>model"
    private let endOfTurn = "<end_of_turn>"
    
    // Vocabulary mappings
    private var tokenToId: [String: Int32] = [:]
    private var idToToken: [Int32: String] = [:]
    
    // Simple regex-based tokenizer patterns
    private let tokenPattern = try! NSRegularExpression(
        pattern: #"'s|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+"#,
        options: [.caseInsensitive]
    )
    
    init(tokenizerURL: URL) throws {
        try loadTokenizer(from: tokenizerURL)
    }
    
    private func loadTokenizer(from url: URL) throws {
        print("🤖 Loading improved Gemma tokenizer...")
        
        // Initialize special tokens
        tokenToId["<pad>"] = padTokenId
        tokenToId["<eos>"] = eosTokenId
        tokenToId["<bos>"] = bosTokenId
        tokenToId["<unk>"] = unkTokenId
        
        idToToken[padTokenId] = "<pad>"
        idToToken[eosTokenId] = "<eos>"
        idToToken[bosTokenId] = "<bos>"
        idToToken[unkTokenId] = "<unk>"
        
        // Add instruction format tokens
        tokenToId[startOfTurnUser] = 4
        tokenToId[startOfTurnModel] = 5
        tokenToId[endOfTurn] = 6
        
        idToToken[4] = startOfTurnUser
        idToToken[5] = startOfTurnModel
        idToToken[6] = endOfTurn
        
        // Try to load from the actual tokenizer.json file
        do {
            let data = try Data(contentsOf: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                try parseTokenizerJson(json)
            }
        } catch {
            print("🤖 Could not parse tokenizer.json, using fallback vocabulary: \(error)")
            addFallbackVocabulary()
        }
        
        print("🤖 Improved tokenizer loaded with \(tokenToId.count) tokens")
    }
    
    private func parseTokenizerJson(_ json: [String: Any]) throws {
        // Try to extract vocabulary from the tokenizer.json
        if let model = json["model"] as? [String: Any],
           let vocab = model["vocab"] as? [String: Any] {
            
            var tokenId: Int32 = 100 // Start after special tokens
            for (token, id) in vocab {
                if let tokenIdNum = id as? NSNumber {
                    let finalId = tokenIdNum.int32Value
                    if finalId >= 100 { // Skip special tokens
                        tokenToId[token] = finalId
                        idToToken[finalId] = token
                        tokenId = max(tokenId, finalId + 1)
                    }
                }
            }
            
            print("🤖 Loaded \(vocab.count) tokens from tokenizer.json")
        } else {
            throw NSError(domain: "TokenizerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid tokenizer.json format"])
        }
    }
    
    private func addFallbackVocabulary() {
        // Enhanced vocabulary with more common tokens and patterns
        let commonTokens = [
            // Punctuation and symbols
            " ", ".", ",", "!", "?", ":", ";", "'", "\"", "-", "_", "(", ")", "[", "]", "{", "}", 
            "\n", "\t", "\r",
            
            // Common English words
            "the", "and", "or", "to", "of", "in", "is", "it", "you", "that", "he", "was", "for", 
            "on", "are", "as", "with", "his", "they", "I", "at", "be", "this", "have", "from", 
            "one", "had", "by", "word", "but", "not", "what", "all", "were", "we", "when", 
            "your", "can", "said", "there", "each", "which", "she", "do", "how", "their", "if", 
            "will", "up", "other", "about", "out", "many", "then", "them", "these", "so", "some", 
            "her", "would", "make", "like", "into", "him", "time", "has", "two", "more", "go", 
            "no", "way", "could", "my", "than", "first", "water", "been", "call", "who", "its", 
            "now", "find", "long", "down", "day", "did", "get", "come", "made", "may", "part",
            
            // Common prefixes and suffixes
            "un", "re", "in", "dis", "en", "non", "pre", "pro", "anti", "de", "over", "under",
            "ing", "ed", "er", "est", "ly", "ion", "tion", "ness", "ment", "ful", "less", "able",
            
            // Numbers and common patterns
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
            "10", "20", "30", "100", "1000",
            
            // Technology and AI related terms
            "AI", "machine", "learning", "model", "data", "algorithm", "neural", "network", 
            "computer", "software", "hardware", "digital", "technology", "internet", "web",
            "app", "application", "system", "code", "program", "programming", "developer",
            
            // Common conversation starters
            "Hello", "Hi", "Hey", "Good", "morning", "afternoon", "evening", "night",
            "How", "What", "Where", "When", "Why", "Who", "Can", "Could", "Would", "Should",
            "Please", "Thank", "thanks", "Sorry", "Excuse", "Help", "Yes", "No", "Maybe",
            "Okay", "OK", "Sure", "Alright", "Fine", "Great", "Good", "Bad", "Nice", "Cool"
        ]
        
        var tokenId: Int32 = 100 // Start after special tokens
        for token in commonTokens {
            if tokenToId[token] == nil {
                tokenToId[token] = tokenId
                idToToken[tokenId] = token
                tokenId += 1
            }
        }
        
        // Add single characters for fallback
        for i in 32...126 { // Printable ASCII characters
            let char = String(Character(UnicodeScalar(i)!))
            if tokenToId[char] == nil {
                tokenToId[char] = tokenId
                idToToken[tokenId] = char
                tokenId += 1
            }
        }
        
        // Add common byte pairs (simplified BPE)
        let commonPairs = [
            "th", "he", "in", "er", "an", "re", "ed", "nd", "on", "en", "at", "ou", "it", "is", "or", "ti", "ar", "te", "ng", "al", "se", "st", "es", "le"
        ]
        
        for pair in commonPairs {
            if tokenToId[pair] == nil {
                tokenToId[pair] = tokenId
                idToToken[tokenId] = pair
                tokenId += 1
            }
        }
    }
    
    func encode(text: String) throws -> [Int32] {
        var tokens: [Int32] = []
        
        // Use regex-based tokenization for better word boundary detection
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = tokenPattern.matches(in: text, options: [], range: range)
        
        for match in matches {
            let matchRange = match.range
            if let swiftRange = Range(matchRange, in: text) {
                let token = String(text[swiftRange])
                
                if let tokenId = tokenToId[token] {
                    tokens.append(tokenId)
                } else {
                    // Try to break down unknown tokens
                    let subTokens = breakDownToken(token)
                    tokens.append(contentsOf: subTokens)
                }
            }
        }
        
        return tokens
    }
    
    private func breakDownToken(_ token: String) -> [Int32] {
        var result: [Int32] = []
        
        // First try to find the longest matching substrings
        var remaining = token
        while !remaining.isEmpty {
            var found = false
            
            // Try progressively shorter substrings
            for length in stride(from: min(remaining.count, 10), through: 1, by: -1) {
                let endIndex = remaining.index(remaining.startIndex, offsetBy: length)
                let substring = String(remaining[remaining.startIndex..<endIndex])
                
                if let tokenId = tokenToId[substring] {
                    result.append(tokenId)
                    remaining = String(remaining[endIndex...])
                    found = true
                    break
                }
            }
            
            if !found {
                // Fallback to first character
                let firstChar = String(remaining.prefix(1))
                if let charId = tokenToId[firstChar] {
                    result.append(charId)
                } else {
                    result.append(unkTokenId)
                }
                remaining = String(remaining.dropFirst())
            }
        }
        
        return result
    }
    
    func decode(tokens: [Int32]) throws -> String {
        var result = ""
        
        for token in tokens {
            if let tokenStr = idToToken[token] {
                // Handle special tokens
                if tokenStr == "<pad>" || tokenStr == "<bos>" {
                    continue // Skip these tokens in output
                }
                if tokenStr == "<eos>" {
                    break // Stop at end of sequence
                }
                
                result += tokenStr
            } else {
                result += "<unk>" // Unknown token
            }
        }
        
        // Clean up the output
        result = result.replacingOccurrences(of: startOfTurnUser, with: "")
        result = result.replacingOccurrences(of: startOfTurnModel, with: "")
        result = result.replacingOccurrences(of: endOfTurn, with: "")
        
        // Clean up extra spaces
        result = result.replacingOccurrences(of: "  ", with: " ")
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Properties for compatibility
    var eosToken: String { return "<eos>" }
    var bosToken: String { return "<bos>" }
    var padToken: String { return "<pad>" }
    var unkToken: String { return "<unk>" }
} 