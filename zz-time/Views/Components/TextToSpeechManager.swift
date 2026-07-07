import AVFoundation
import SwiftUI

enum ContentMode: String, Codable {
    case off = "off"
    case story = "story"
    case poetry = "poetry"

    func next() -> ContentMode {
        switch self {
        case .off: return .story
        case .story: return .poetry
        case .poetry: return .off
        }
    }
}

enum StoryState: Equatable {
    case idle                           // No story playing
    case starting(sessionId: UUID)      // Transitioning to play
    case playing(sessionId: UUID)       // Actively playing
    case stopping(sessionId: UUID)      // Transitioning to stop

    var isTransitioning: Bool {
        switch self {
        case .starting, .stopping: return true
        case .idle, .playing: return false
        }
    }

    var sessionId: UUID? {
        switch self {
        case .idle: return nil
        case .starting(let id), .playing(let id), .stopping(let id): return id
        }
    }
}

/// A simple manager for text-to-speech using AVSpeechSynthesizer.
/// This uses the built-in iOS voices without requiring any downloads.
@MainActor
class TextToSpeechManager: ObservableObject {
    @Published private(set) var storyState: StoryState = .idle

    // Backward compatibility computed properties for UI
    var isSpeaking: Bool {
        switch storyState {
        case .starting, .playing: return true
        case .idle, .stopping: return false
        }
    }

    var isPlayingStory: Bool {
        switch storyState {
        case .playing: return true
        case .idle, .starting, .stopping: return false
        }
    }

    @Published var audioBalance: Double = 1.0  // 0.0 (0% ambient) to 1.0 (100% ambient), default 100%

    // Closed captioning support
    @Published var currentPhrase: String = ""
    @Published var previousPhrase: String = ""
    @Published var phraseHistory: [String] = []  // Full history of all spoken phrases
    @Published var hasNewCaptionContent: Bool = false  // Indicates new content while user is scrolled up

    var synthesizer = AVSpeechSynthesizer()  // Internal access for pause/resume from VoiceSettingsView
    private var speechDelegate: SpeechDelegate
    private var repeatCount = 0
    private let maxRepeats = 10
    private var isCustomMode: Bool = false
    private var queuedUtteranceCount: Int = 0
    private static let storySpeechRate: Float = 1.0  // Calm, slow rate for story
    private static let storyPitchMultiplier: Float = 1.0  // Slightly lower pitch for calmer

    // Wake-up greeting phrases (randomly selected when alarm triggers after story completion)
    private static let wakeUpGreetings: [String] = [
        "Welcome back",
        "Greetings",
        "Here we are",
        "Returning to awareness",
        "Welcome back to this space"
    ]

    // Track phrases for closed captioning
    private var allPhrases: [String] = []
    private var currentPhraseIndex: Int = 0

    // Reference to custom story manager for random selection
    weak var customStoryManager: CustomStoryManager?

    // Reference to custom poem manager for random selection
    weak var customPoemManager: CustomPoemManager?

    // Reference to story collection manager for multi-story support
    weak var storyCollectionManager: StoryCollectionManager?

    // Current content mode
    @Published var currentContentMode: ContentMode = .off

    // Callback to notify when ambient volume changes
    var onAmbientVolumeChanged: ((Float) -> Void)? = nil

    var voiceVolume: Float {
        AudioConstants.ttsVolume
    }

    var ambientVolume: Float {
        // Balance ranges from 0.0 (0% ambient) to 1.0 (100% ambient)
        // At 0.0: ambient = 0.0
        // At 1.0: ambient = AudioConstants.ambientMaxVolume (boosted max)
        return Float(audioBalance * Double(AudioConstants.ambientMaxVolume))
    }
    
    init() {
        let delegate = SpeechDelegate()
        speechDelegate = delegate
        synthesizer.delegate = speechDelegate
        delegate.manager = self
    }
    
    /// Call this whenever the balance changes to notify the callback
    func updateVolumesFromBalance() {
        onAmbientVolumeChanged?(ambientVolume)
    }

    // MARK: - State Machine

    private func transitionState(to newState: StoryState, reason: String) -> Bool {
        let oldState = storyState

        guard isValidTransition(from: oldState, to: newState) else {
            return false
        }

        storyState = newState
        return true
    }

    private func isValidTransition(from old: StoryState, to new: StoryState) -> Bool {
        switch (old, new) {
        case (.idle, .starting): return true
        case (.starting, .playing): return true
        case (.playing, .stopping): return true
        case (.stopping, .idle): return true
        case (.playing, .starting): return true  // Long-press skip
        case (.idle, .idle), (.playing, .playing), (.starting, .starting), (.stopping, .stopping):
            return true  // Idempotent
        default: return false
        }
    }

    /// Recreates the synthesizer instance to clear any corrupted internal state
    private func recreateSynthesizer() {
        // Stop the old synthesizer
        synthesizer.stopSpeaking(at: .immediate)

        // Create new instances
        synthesizer = AVSpeechSynthesizer()
        speechDelegate = SpeechDelegate()
        speechDelegate.manager = self
        synthesizer.delegate = speechDelegate
    }

    /// Called when voice settings have changed to ensure the new voice will be used
    /// This recreates the synthesizer to clear any cached voice state
    func refreshVoiceSettings() {
        // Only recreate if not currently speaking
        // If speaking, the next story/poem will pick up the new voice automatically
        guard !isSpeaking else { return }

        recreateSynthesizer()
    }

    /// Starts speaking the test phrase, repeating 10 times
    func startSpeaking() {
        guard !isSpeaking else { return }

        let newSessionId = UUID()
        _ = transitionState(to: .starting(sessionId: newSessionId), reason: "Start speaking test phrases")
        _ = transitionState(to: .playing(sessionId: newSessionId), reason: "Playing test phrases")

        isCustomMode = false
        repeatCount = 0
        speakNextPhrase()
    }
    
    /// Starts speaking custom text (only once, no repeating)
    func startSpeakingCustomText(_ text: String) {
        guard !isSpeaking else { return }
        guard !text.isEmpty else { return }

        let newSessionId = UUID()
        _ = transitionState(to: .starting(sessionId: newSessionId), reason: "Start speaking custom text")
        _ = transitionState(to: .playing(sessionId: newSessionId), reason: "Playing custom text")

        isCustomMode = true

        let utterance = AVSpeechUtterance(string: text)
        let voice = VoiceManager.shared.getPreferredVoice()
        let speechRateMultiplier = VoiceManager.shared.getSpeechRateMultiplier(for: voice)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRateMultiplier
        utterance.pitchMultiplier = Self.storyPitchMultiplier
        utterance.volume = voiceVolume
        utterance.voice = voice

        synthesizer.speak(utterance)
    }
    
    func getSequentialStory() -> String? {
        guard let manager = storyCollectionManager,
              let collection = manager.selectedCollection else {
            return nil
        }

        let chapterIndex = manager.getChapterIndex(for: collection.directoryName)
        return manager.getStoryText(for: collection, chapterIndex: chapterIndex)
    }

    func skipToNextChapter(startIfPlaying: Bool = true) {
        guard let manager = storyCollectionManager,
              let collection = manager.selectedCollection else { return }

        let currentIndex = manager.getChapterIndex(for: collection.directoryName)
        let sortedChapters = collection.sortedChapters

        // Find next chapter or wrap to first
        if let currentIdx = sortedChapters.firstIndex(where: { $0.sequenceNumber == currentIndex }),
           currentIdx + 1 < sortedChapters.count {
            let nextChapter = sortedChapters[currentIdx + 1]
            manager.setChapterIndex(nextChapter.sequenceNumber, for: collection.directoryName)
        } else if let first = sortedChapters.first {
            manager.setChapterIndex(first.sequenceNumber, for: collection.directoryName)
        }

        // If playing and requested, start the new chapter
        if startIfPlaying && isPlayingStory {
            if let text = getSequentialStory() {
                Task {
                    await stopSpeaking()
                    startSpeakingWithPauses(text)
                }
            }
        }
    }

    func skipToPreviousChapter(startIfPlaying: Bool = true) {
        guard let manager = storyCollectionManager,
              let collection = manager.selectedCollection else { return }

        let currentIndex = manager.getChapterIndex(for: collection.directoryName)
        let sortedChapters = collection.sortedChapters

        // Find previous chapter or wrap to last
        if let currentIdx = sortedChapters.firstIndex(where: { $0.sequenceNumber == currentIndex }),
           currentIdx > 0 {
            let prevChapter = sortedChapters[currentIdx - 1]
            manager.setChapterIndex(prevChapter.sequenceNumber, for: collection.directoryName)
        } else if let last = sortedChapters.last {
            manager.setChapterIndex(last.sequenceNumber, for: collection.directoryName)
        }

        // If playing and requested, start the new chapter
        if startIfPlaying && isPlayingStory {
            if let text = getSequentialStory() {
                Task {
                    await stopSpeaking()
                    startSpeakingWithPauses(text)
                }
            }
        }
    }

    func getRandomPoem() -> String? {
        guard let manager = storyCollectionManager else { return nil }
        return manager.getRandomPoem()
    }

    /// Starts speaking a random story from text files
    func startSpeakingRandomStory() {
        guard !isSpeaking else { return }

        // Try to load a random story file
        guard let storyText = loadRandomStoryFile() else {
            return
        }

        let newSessionId = UUID()
        _ = transitionState(to: .starting(sessionId: newSessionId), reason: "Start random story")
        _ = transitionState(to: .playing(sessionId: newSessionId), reason: "Playing random story")

        isCustomMode = true  // Treat like custom - play once, don't repeat

        let utterance = AVSpeechUtterance(string: storyText)
        let voice = VoiceManager.shared.getPreferredVoice()
        let speechRateMultiplier = VoiceManager.shared.getSpeechRateMultiplier(for: voice)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRateMultiplier
        utterance.pitchMultiplier = Self.storyPitchMultiplier
        utterance.volume = voiceVolume
        utterance.voice = voice

        synthesizer.speak(utterance)
    }
    
    /// Removes lines that consist entirely of visual separators (asterisks, dashes, underscores)
    /// so TTS does not literally speak "asterisk", "dash", or "underscore" for section breaks.
    private func preprocessTextForSpeech(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        let processedLines = lines.map { line -> String in
            let stripped = line.trimmingCharacters(in: .whitespaces)
            guard !stripped.isEmpty else { return line }
            let onlyAsterisks   = stripped.allSatisfy { $0 == "*" || $0 == " " }
            let onlyDashes      = stripped.allSatisfy { $0 == "-" || $0 == "—" || $0 == " " }
            let onlyUnderscores = stripped.allSatisfy { $0 == "_" || $0 == " " }
            return (onlyAsterisks || onlyDashes || onlyUnderscores) ? "" : line
        }
        return processedLines.joined(separator: "\n")
    }

    /// Automatically adds pauses to text: splits into sentences and adds 0.5s between sentences, 2s between paragraphs
    /// Uses special marker "<<PARAGRAPH_BREAK>>" to indicate paragraph boundaries for caption display
    private func addAutomaticPauses(to text: String) -> String {
        var result = ""
        let paragraphs = text.components(separatedBy: .newlines)

        for (paragraphIndex, paragraph) in paragraphs.enumerated() {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines
            guard !trimmed.isEmpty else {
                continue
            }

            // Split paragraph into sentences using sentence boundary detection
            let sentences = splitIntoSentences(trimmed)

            for (sentenceIndex, sentence) in sentences.enumerated() {
                let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedSentence.isEmpty else { continue }

                result += trimmedSentence

                // Add small pause between sentences (except after the last sentence in last paragraph)
                let isLastSentenceInParagraph = (sentenceIndex == sentences.count - 1)
                let isLastParagraph = (paragraphIndex == paragraphs.count - 1)

                if !isLastSentenceInParagraph {
                    // 0.5s pause between sentences within a paragraph
                    result += " (0.5s)\n"
                } else if !isLastParagraph {
                    // 2s pause between paragraphs + special marker for caption display
                    result += " <<PARAGRAPH_BREAK>> (2s)\n"
                } else {
                    result += "\n"
                }
            }
        }

        return result
    }

    /// Splits text into sentences based on sentence-ending punctuation
    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var currentSentence = ""
        var i = text.startIndex

        while i < text.endIndex {
            let char = text[i]
            currentSentence.append(char)

            // Check for sentence-ending punctuation: . ! ?
            if char == "." || char == "!" || char == "?" {
                // Look ahead to see if this is a sentence boundary
                let nextIndex = text.index(after: i)

                // If we're at the end, it's definitely a sentence
                if nextIndex >= text.endIndex {
                    sentences.append(currentSentence)
                    currentSentence = ""
                } else {
                    let nextChar = text[nextIndex]

                    // Check if followed by space or end of text (sentence boundary)
                    // Also check for common abbreviations to avoid false splits
                    let isPotentialAbbreviation = char == "." && currentSentence.count >= 3 &&
                        (currentSentence.hasSuffix("Dr.") ||
                         currentSentence.hasSuffix("Mr.") ||
                         currentSentence.hasSuffix("Mrs.") ||
                         currentSentence.hasSuffix("Ms.") ||
                         currentSentence.hasSuffix("vs.") ||
                         currentSentence.hasSuffix("etc.") ||
                         currentSentence.hasSuffix("e.g.") ||
                         currentSentence.hasSuffix("i.e."))

                    if !isPotentialAbbreviation && (nextChar == " " || nextChar == "\n") {
                        sentences.append(currentSentence)
                        currentSentence = ""
                    }
                }
            }

            i = text.index(after: i)
        }

        // Add any remaining text as the last sentence
        if !currentSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sentences.append(currentSentence)
        }

        return sentences
    }
    
    /// Starts speaking text with embedded pauses like "(4s)" – splits into utterances automatically
    func startSpeakingWithPauses(_ text: String) {
        guard !text.isEmpty else {
            return
        }

        let newSessionId = UUID()

        // CRITICAL: Recreate synthesizer on each story start to avoid corruption
        recreateSynthesizer()

        // Transition to STARTING state FIRST
        guard transitionState(to: .starting(sessionId: newSessionId), reason: "User started story") else {
            return
        }

        // Reset state variables AFTER state transition
        queuedUtteranceCount = 0
        repeatCount = 0
        currentPhrase = ""
        previousPhrase = ""
        phraseHistory = []
        allPhrases = []
        currentPhraseIndex = 0

        // Clear any previous story completion flag
        UserDefaults.standard.removeObject(forKey: "contentCompletedSuccessfully")

        // Pre-process: strip lines that are purely decorative separators (asterisks, dashes, underscores)
        // so TTS doesn't literally speak "asterisk", "dash", or "underscore"
        let preprocessedText = preprocessTextForSpeech(text)

        // Check if text has any pause markers
        let hasPauseMarkers = preprocessedText.range(of: #"\(\d+(?:\.\d+)?[sm]\)"#, options: .regularExpression) != nil

        // If no pause markers found, add automatic ones
        let processedText = hasPauseMarkers ? preprocessedText : addAutomaticPauses(to: preprocessedText)

        // Split by both newlines and pause markers
        let phrases = extractPhrasesWithPauses(from: processedText)

        // Filter out empty phrases first
        let validPhrases = phrases.filter { !$0.phrase.isEmpty }

        // Clean all phrases and filter again (safety check for pause markers)
        let cleanedPhrases: [(phrase: String, delay: TimeInterval)] = validPhrases.compactMap { (phrase, delay) in
            // CRITICAL SAFETY CHECK: Remove any pause markers that might have slipped through
            // This prevents iOS from speaking pause markers like "(14s)" as "pause equals fourteen thousand"
            let cleanPhrase = phrase.replacingOccurrences(
                of: #"\(\d+(?:\.\d+)?[sm]\)"#,
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            return cleanPhrase.isEmpty ? nil : (cleanPhrase, delay)
        }

        // ULTRA-CLEAN all phrases one more time before using them
        let ultraCleanedPhrases: [(phrase: String, delay: TimeInterval, isParagraphBreak: Bool)] = cleanedPhrases.compactMap { (phrase, delay) in
            // Check if this phrase contains the paragraph break marker
            let isParagraphBreak = phrase.contains("<<PARAGRAPH_BREAK>>")

            // ULTRA-PARANOID SAFETY CHECK: Strip ALL parenthetical content AND paragraph markers
            var ultraCleanPhrase = phrase

            // Remove paragraph break marker
            ultraCleanPhrase = ultraCleanPhrase.replacingOccurrences(
                of: "<<PARAGRAPH_BREAK>>",
                with: ""
            )

            // First try the specific regex
            ultraCleanPhrase = ultraCleanPhrase.replacingOccurrences(
                of: #"\(\d+(?:\.\d+)?[sm]\)"#,
                with: "",
                options: .regularExpression
            )

            // Nuclear option: remove ANY content in parentheses that looks like a pause
            ultraCleanPhrase = ultraCleanPhrase.replacingOccurrences(
                of: #"\([0-9][^)]*\)"#,
                with: "",
                options: .regularExpression
            )

            ultraCleanPhrase = ultraCleanPhrase.trimmingCharacters(in: .whitespacesAndNewlines)

            return ultraCleanPhrase.isEmpty ? nil : (ultraCleanPhrase, delay, isParagraphBreak)
        }

        // CRITICAL BUG FIX: Validate that we have content to speak before setting state
        // If text processing resulted in no speakable content, don't show story as playing
        guard !ultraCleanedPhrases.isEmpty else {
            _ = transitionState(to: .idle, reason: "No valid content")
            return
        }

        // Store ULTRA-cleaned phrases for closed captioning with paragraph break info
        // Format: "PHRASE" or "PHRASE<<PB>>" where <<PB>> indicates paragraph break after this phrase
        allPhrases = ultraCleanedPhrases.map { phrase, _, isParagraphBreak in
            isParagraphBreak ? phrase + "<<PB>>" : phrase
        }

        // Calculate total utterance count (speech + silent pause utterances)
        var totalUtteranceCount = 0
        for (_, delay, _) in ultraCleanedPhrases {
            totalUtteranceCount += 1  // Count the speech utterance

            // Count silent pause utterances
            if delay > 0 {
                let numPauses = Int(ceil(delay / 5.0))  // Break into 5-second chunks
                totalUtteranceCount += numPauses
            }
        }

        // Set the count of ALL utterances we're about to queue (speech + silent)
        queuedUtteranceCount = totalUtteranceCount
        isCustomMode = true

        // CRITICAL: Get the voice ONCE before the loop to ensure all utterances use the same voice
        // If we call getPreferredVoice() inside the loop, it will return a different random voice
        // for each utterance when no voice preference is saved
        let voice = VoiceManager.shared.getPreferredVoice()
        let speechRateMultiplier = VoiceManager.shared.getSpeechRateMultiplier(for: voice)

        // Auto-save the voice preference for first-time users
        // This ensures the same random voice is used across all story sessions
        // until the user explicitly selects a different voice in Voice Settings
        if VoiceManager.shared.preferredVoiceIdentifier == nil {
            VoiceManager.shared.preferredVoiceIdentifier = voice?.identifier
        }

        // Queue ALL utterances FIRST before transitioning to playing
        for (ultraCleanPhrase, delay, _) in ultraCleanedPhrases {
            // Strip italic markers so the voice doesn't say "asterisk"
            let ttsPhrase = ultraCleanPhrase.replacingOccurrences(of: "*", with: "")
            let utterance = AVSpeechUtterance(string: ttsPhrase)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRateMultiplier
            utterance.pitchMultiplier = Self.storyPitchMultiplier
            utterance.volume = voiceVolume
            utterance.voice = voice

            // Tag this utterance with the session ID so we can validate callbacks
            speechDelegate.tagUtterance(utterance, withSessionId: newSessionId)

            synthesizer.speak(utterance)

            // For pauses, queue multiple silent utterances to create the pause
            // This avoids the bug where postUtteranceDelay causes iOS to speak the delay value
            if delay > 0 {
                let numPauses = Int(ceil(delay / 5.0))  // Break into 5-second chunks
                let pausePerChunk = delay / Double(numPauses)

                for _ in 0..<numPauses {
                    let silentUtterance = AVSpeechUtterance(string: "")  // Empty string for silence
                    silentUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
                    silentUtterance.volume = 0.0  // Silent
                    silentUtterance.postUtteranceDelay = pausePerChunk
                    silentUtterance.voice = AVSpeechSynthesisVoice(language: "en-US")

                    // Tag silent utterances with session ID too
                    speechDelegate.tagUtterance(silentUtterance, withSessionId: newSessionId)

                    synthesizer.speak(silentUtterance)
                }
            }
        }

        // Transition to PLAYING state
        guard transitionState(to: .playing(sessionId: newSessionId), reason: "Utterances queued") else {
            _ = transitionState(to: .idle, reason: "Transition failed")
            return
        }
    }

    /// Extracts phrases and their associated pauses from text
    private func extractPhrasesWithPauses(from text: String) -> [(phrase: String, delay: TimeInterval)] {
        var result: [(String, TimeInterval)] = []

        // Pattern to match pause markers anywhere in text: (3s), (2.5s), (1m), (1.5m), etc.
        let pattern = #"\((\d+(?:\.\d+)?)(s|m)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            // If regex fails, return the whole text with no delay
            return [(text.trimmingCharacters(in: .whitespacesAndNewlines), 0.0)]
        }

        // First, let's extract all matches and their delays
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        // If no matches, return the whole text
        guard !matches.isEmpty else {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return [(trimmed, 0.0)]
            }
            return []
        }

        var lastIndex = text.startIndex

        for match in matches {
            guard let matchRange = Range(match.range, in: text) else { continue }

            // Get the phrase before this pause marker
            let phraseBeforePause = String(text[lastIndex..<matchRange.lowerBound])

            // Get the pause duration and unit
            guard let durationRange = Range(match.range(at: 1), in: text),
                  let unitRange = Range(match.range(at: 2), in: text),
                  let value = Double(text[durationRange]) else {
                continue
            }

            let unit = String(text[unitRange])

            // Convert to seconds
            let seconds: TimeInterval = {
                switch unit {
                case "m":
                    return value * 60.0  // Convert minutes to seconds
                case "s":
                    return value
                default:
                    return value  // Default to seconds
                }
            }()

            let trimmedPhrase = phraseBeforePause.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPhrase.isEmpty {
                result.append((trimmedPhrase, seconds))
            }

            // Move past this pause marker
            lastIndex = matchRange.upperBound
        }

        // Add any remaining text after the last pause marker (with no delay)
        let remainingText = String(text[lastIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)

        // CRITICAL: Remove any pause markers from remaining text as a safety check
        // This ensures no pause markers accidentally get spoken
        let cleanedRemainingText = remainingText.replacingOccurrences(
            of: #"\(\d+(?:\.\d+)?[sm]\)"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleanedRemainingText.isEmpty {
            result.append((cleanedRemainingText, 0.0))
        }

        return result
    }
        
    /// Loads a random story text file from the bundle (checks up to 100 preset files)
    private func loadRandomStoryFile() -> String? {
        // Load all available preset story files (check up to 100 to future-proof)
        var validURLs: [URL] = []

        for i in 1...100 {
            if let url = Bundle.main.url(forResource: "preset_story\(i)", withExtension: "txt") {
                validURLs.append(url)
            }
        }
        
        guard !validURLs.isEmpty else {
            return nil
        }

        // Pick a random preset story file
        let randomURL = validURLs.randomElement()!

        // Load the text
        guard let text = try? String(contentsOf: randomURL, encoding: .utf8) else {
            return nil
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Speaks a random wake-up greeting (used when alarm triggers after story completion)
    func speakWakeUpGreeting() {
        guard let greeting = Self.wakeUpGreetings.randomElement() else { return }

        let utterance = AVSpeechUtterance(string: greeting)
        let voice = VoiceManager.shared.getPreferredVoice()
        let speechRateMultiplier = VoiceManager.shared.getSpeechRateMultiplier(for: voice)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * speechRateMultiplier
        utterance.pitchMultiplier = Self.storyPitchMultiplier
        utterance.volume = voiceVolume
        utterance.voice = voice

        synthesizer.speak(utterance)
    }

    /// Stops speaking immediately
    func stopSpeaking() async {
        await withCheckedContinuation { continuation in
            stopSpeakingInternal {
                continuation.resume()
            }
        }
    }

    private func stopSpeakingInternal(completion: @escaping () -> Void) {
        guard let currentSessionId = storyState.sessionId else {
            completion()
            return
        }

        guard transitionState(to: .stopping(sessionId: currentSessionId), reason: "User stopped") else {
            completion()
            return
        }

        synthesizer.stopSpeaking(at: .immediate)

        // Reset state variables
        queuedUtteranceCount = 0
        repeatCount = 0
        currentPhrase = ""
        previousPhrase = ""
        phraseHistory = []
        allPhrases = []
        currentPhraseIndex = 0
        isCustomMode = false

        // Clear story completion flag since it was stopped manually
        UserDefaults.standard.removeObject(forKey: "contentCompletedSuccessfully")

        // Transition to idle immediately
        _ = transitionState(to: .idle, reason: "Stop completed")
        completion()
    }

    // MARK: - Content Mode Management

    func cycleContentMode() {
        let newMode = currentContentMode.next()
        currentContentMode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: "contentMode")

        // Persist preference for session restoration
        if newMode != .off {
            UserDefaults.standard.set(newMode.rawValue, forKey: "lastContentMode")
        }
    }

    func restoreLastSession() {
        guard let savedMode = UserDefaults.standard.string(forKey: "lastContentMode"),
              let mode = ContentMode(rawValue: savedMode) else { return }

        currentContentMode = mode

        // Auto-start content based on mode
        switch mode {
        case .story:
            if let text = getSequentialStory() {
                startSpeakingWithPauses(text)
            }
        case .poetry:
            if let text = getRandomPoem() {
                startSpeakingWithPauses(text)
            }
        case .off:
            break
        }
    }

    // MARK: - Private Methods

    private func speakNextPhrase() {
        guard isSpeaking && repeatCount < maxRepeats else {
            _ = transitionState(to: .idle, reason: "Repeats exhausted")
            return
        }
        
        let utterance = AVSpeechUtterance(string: "All work and no play makes Jack a dull boy.")
        
        // Configure the voice - using the default system voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * Self.storySpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = voiceVolume
        utterance.pitchMultiplier = Self.storyPitchMultiplier
        
        // Use default US English voice
        if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        synthesizer.speak(utterance)
        repeatCount += 1
    }
    
    // Called by the delegate when an utterance starts
    fileprivate func didStartUtterance(_ utterance: AVSpeechUtterance, sessionId: UUID) {
        // Only update closed captioning for actual speech (not silent utterances)
        // Silent utterances have empty strings
        guard !utterance.speechString.isEmpty else {
            return
        }

        // Update closed captioning when a phrase starts speaking
        if currentPhraseIndex < allPhrases.count {
            let newPhrase = allPhrases[currentPhraseIndex]
            previousPhrase = currentPhrase
            currentPhrase = newPhrase

            // Add to phrase history (avoid duplicates)
            if phraseHistory.isEmpty || phraseHistory.last != newPhrase {
                phraseHistory.append(newPhrase)
            }
        }
    }

    // Called by the delegate when speech finishes
    fileprivate func didFinishSpeaking(_ utterance: AVSpeechUtterance, sessionId: UUID) {
        // Validate callback belongs to current state's session
        guard let currentSessionId = storyState.sessionId else {
            return
        }

        guard sessionId == currentSessionId else {
            return
        }

        guard case .playing = storyState else {
            return
        }

        // If custom mode (story), update closed captioning and track utterance completion
        if isCustomMode {
            // Only increment phrase index for actual speech (not silent utterances)
            if !utterance.speechString.isEmpty {
                currentPhraseIndex += 1  // Move to next phrase for closed captioning
            }

            // Decrement the queued utterance count (this counts both speech AND silent utterances)
            queuedUtteranceCount -= 1

            // Only stop when all utterances are done
            if queuedUtteranceCount <= 0 {
                _ = transitionState(to: .idle, reason: "All utterances finished")
                isCustomMode = false
                queuedUtteranceCount = 0
                currentPhrase = ""
                previousPhrase = ""
                phraseHistory = []

                // Mark that a story completed successfully (for wake-up greeting feature)
                UserDefaults.standard.set(true, forKey: "contentCompletedSuccessfully")

                // Advance to next chapter for sequential story playback
                skipToNextChapter(startIfPlaying: false)
            }
            return
        }

        // Handle non-story mode (existing logic)
        if repeatCount < maxRepeats {
            // Small pause between repetitions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.speakNextPhrase()
            }
        } else {
            _ = transitionState(to: .idle, reason: "Repeats complete")
        }
    }
}

// Delegate to handle speech events
private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    weak var manager: TextToSpeechManager?

    // Dictionary to track which session each utterance belongs to
    private var utteranceSessionIds: [ObjectIdentifier: UUID] = [:]
    private let lock = NSLock()

    override init() {
        super.init()
    }

    /// Tag an utterance with a session ID before speaking it
    func tagUtterance(_ utterance: AVSpeechUtterance, withSessionId sessionId: UUID) {
        lock.lock()
        defer { lock.unlock() }
        utteranceSessionIds[ObjectIdentifier(utterance)] = sessionId
    }

    /// Get the session ID for an utterance, if it was tagged
    private func getSessionId(for utterance: AVSpeechUtterance) -> UUID? {
        lock.lock()
        defer { lock.unlock() }
        let id = utteranceSessionIds[ObjectIdentifier(utterance)]
        return id
    }

    /// Remove the session ID tracking for an utterance (cleanup)
    private func removeSessionId(for utterance: AVSpeechUtterance) {
        lock.lock()
        defer { lock.unlock() }
        utteranceSessionIds.removeValue(forKey: ObjectIdentifier(utterance))
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let utteranceSessionId = getSessionId(for: utterance) ?? UUID()

        DispatchQueue.main.async { [weak manager] in
            manager?.didStartUtterance(utterance, sessionId: utteranceSessionId)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let utteranceSessionId = getSessionId(for: utterance) ?? UUID()

        removeSessionId(for: utterance)

        DispatchQueue.main.async { [weak manager] in
            manager?.didFinishSpeaking(utterance, sessionId: utteranceSessionId)
        }
    }
}
