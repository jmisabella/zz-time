import SwiftUI

struct StoryTextDisplay: View {
    let currentPhrase: String
    let previousPhrase: String

    private func styledText(_ text: String) -> Text {
        let clean = text.replacingOccurrences(of: "<<PB>>", with: "")
        if let attributed = try? AttributedString(markdown: clean, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            return Text(attributed)
        }
        return Text(clean)
    }

    var body: some View {
        // Only show the caption box if there's text to display
        if !currentPhrase.isEmpty || !previousPhrase.isEmpty {
            ZStack {
                // Semi-transparent dark rounded rectangle
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.55))

                VStack(spacing: 8) {
                    // Previous phrase (centered, faded)
                    if !previousPhrase.isEmpty {
                        styledText(previousPhrase)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Current phrase (centered, full brightness)
                    if !currentPhrase.isEmpty {
                        styledText(currentPhrase)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(16) // Internal padding
            }
            .fixedSize(horizontal: false, vertical: true) // Wrap to content height
            .padding(.horizontal, 24) // Margins from screen edges
        }
    }
}

#Preview {
    ZStack {
        Color.blue.ignoresSafeArea()

        StoryTextDisplay(
            currentPhrase: "Notice your breath for a moment.",
            previousPhrase: "Close your eyes and settle in."
        )
    }
}
