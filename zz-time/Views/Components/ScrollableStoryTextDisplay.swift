import SwiftUI

struct ScrollableStoryTextDisplay: View {
    let phraseHistory: [String]
    let currentPhrase: String
    @Binding var hasNewContent: Bool

    @State private var scrollViewProxy: ScrollViewProxy?
    @State private var isUserScrolling = false
    @State private var isAtBottom = true

    var body: some View {
        if !phraseHistory.isEmpty || !currentPhrase.isEmpty {
            ZStack(alignment: .bottom) {
                // Semi-transparent dark rounded rectangle
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.55))

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            // Display all phrases in history, with the last one highlighted as current
                            ForEach(Array(phraseHistory.enumerated()), id: \.offset) { index, phrase in
                                let isCurrentPhrase = (index == phraseHistory.count - 1) && phrase == currentPhrase

                                Text(phrase)
                                    .font(.system(size: isCurrentPhrase ? 18 : 16, weight: isCurrentPhrase ? .medium : .regular))
                                    .foregroundColor(isCurrentPhrase ? .white : .white.opacity(0.7))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(index)
                            }

                            // Invisible anchor at the bottom for scrolling
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(16)
                    }
                    .frame(maxHeight: 100) // Compact height for the scrollable area
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
            .frame(height: 100) // Constrain the entire ZStack height
            .padding(.horizontal, 24)
        }
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
