import SwiftUI

struct ScrollableStoryTextDisplay: View {
    let phraseHistory: [String]
    let currentPhrase: String
    @Binding var hasNewContent: Bool

    private func styledText(_ text: String) -> Text {
        let clean = text.replacingOccurrences(of: "<<PB>>", with: "")
        if let attributed = try? AttributedString(markdown: clean, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed)
        }
        return Text(clean)
    }

    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var isUserScrolling = false
    @State private var isAtBottom = true

    // Detect device orientation to adjust caption box height
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }

    private var captionHeight: CGFloat {
        // Use smaller height in landscape to avoid covering sliders
        isLandscape ? 150 : 300
    }

    var body: some View {
        if !phraseHistory.isEmpty || !currentPhrase.isEmpty {
            ZStack(alignment: .bottom) {
                // Semi-transparent dark rounded rectangle
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.55))

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            // Group phrases into paragraphs for historical display
                            let groupedPhrases = groupIntoParagraphs(phraseHistory)

                            ForEach(Array(groupedPhrases.enumerated()), id: \.offset) { groupIndex, paragraphPhrases in
                                let isLastGroup = groupIndex == groupedPhrases.count - 1

                                // Check if the current phrase is in this group
                                let containsCurrentPhrase = isLastGroup && paragraphPhrases.last == currentPhrase

                                if containsCurrentPhrase {
                                    // For the group containing current phrase, show each sentence separately
                                    ForEach(Array(paragraphPhrases.enumerated()), id: \.offset) { sentenceIndex, phrase in
                                        let isCurrentSentence = phrase == currentPhrase

                                        styledText(phrase)
                                            .font(.system(size: isCurrentSentence ? 18 : 16, weight: isCurrentSentence ? .medium : .regular))
                                            .foregroundColor(isCurrentSentence ? .white : .white.opacity(0.7))
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .id("group\(groupIndex)_sentence\(sentenceIndex)")
                                    }
                                } else {
                                    // For historical paragraphs, combine sentences into one paragraph
                                    styledText(paragraphPhrases.joined(separator: " "))
                                        .font(.system(size: 16, weight: .regular))
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id("group\(groupIndex)")
                                }
                            }

                            // Invisible anchor at the bottom for scrolling
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(16)
                    }
                    .frame(maxHeight: captionHeight) // Responsive height based on orientation
                    .onAppear {
                        scrollViewProxy = proxy
                        // Start at bottom
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: currentPhrase) { _ in
                        // Only auto-scroll if user is at bottom (not manually scrolled up)
                        if isAtBottom && !isUserScrolling {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                            hasNewContent = false
                            isAtBottom = true
                        } else if !isAtBottom {
                            // User has scrolled up, indicate new content is available
                            hasNewContent = true
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 5)
                            .onChanged { _ in
                                if !isUserScrolling {
                                    isUserScrolling = true
                                    isAtBottom = false
                                }
                            }
                            .onEnded { _ in
                                isUserScrolling = false
                            }
                    )
                }

                // "New text available" indicator when user is scrolled up
                if hasNewContent && !isAtBottom {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    scrollViewProxy?.scrollTo("bottom", anchor: .bottom)
                                    hasNewContent = false
                                    isAtBottom = true
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 14))
                                    Text("New text")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.9))
                                .foregroundColor(.black)
                                .cornerRadius(20)
                            }
                            Spacer()
                        }
                        .padding(.bottom, 8)
                    }
                }
            }
            .frame(height: captionHeight) // Constrain the entire ZStack height based on orientation
            .padding(.horizontal, 24)
        }
    }

    // Groups phrases into paragraphs based on the <<PB>> marker
    private func groupIntoParagraphs(_ phrases: [String]) -> [[String]] {
        var paragraphs: [[String]] = []
        var currentParagraph: [String] = []

        for phrase in phrases {
            // Check if this phrase has the paragraph break marker
            if phrase.hasSuffix("<<PB>>") {
                // Remove the marker and add to current paragraph
                let cleanPhrase = String(phrase.dropLast(6)) // Remove "<<PB>>"
                currentParagraph.append(cleanPhrase)
                // Start new paragraph
                paragraphs.append(currentParagraph)
                currentParagraph = []
            } else {
                currentParagraph.append(phrase)
            }
        }

        // Add any remaining phrases as the final paragraph
        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph)
        }

        return paragraphs
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()

        ScrollableStoryTextDisplay(
            phraseHistory: [
                "Welcome to this story.",
                "Find a comfortable position.",
                "Close your eyes gently.",
                "Begin to notice your breath.",
                "Feel the air entering your nostrils.",
                "And leaving your body."
            ],
            currentPhrase: "Simply observe without judgment.",
            hasNewContent: .constant(false)
        )
    }
}
