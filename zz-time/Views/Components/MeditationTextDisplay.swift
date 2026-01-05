import SwiftUI

struct MeditationTextDisplay: View {
    let currentPhrase: String
    let previousPhrase: String

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
                        Text(previousPhrase)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Current phrase (centered, full brightness)
                    if !currentPhrase.isEmpty {
                        Text(currentPhrase)
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

        MeditationTextDisplay(
            currentPhrase: "Notice your breath for a moment.",
            previousPhrase: "Close your eyes and settle in."
        )
    }
}
