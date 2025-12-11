import SwiftUI

struct MeditationTextDisplay: View {
    let currentPhrase: String
    let previousPhrase: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            // Gradient overlay container
            ZStack(alignment: .bottom) {
                // Semi-transparent gradient overlay
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color.black.opacity(0), location: 0),
                        .init(color: Color.black.opacity(0.4), location: 0.5),
                        .init(color: Color.black.opacity(0.7), location: 1.0)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)

                // Text content
                VStack(alignment: .leading, spacing: 8) {
                    // Previous phrase (faded)
                    if !previousPhrase.isEmpty {
                        Text(previousPhrase)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    // Current phrase (fully visible)
                    if !currentPhrase.isEmpty {
                        Text(currentPhrase)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .padding(.bottom, 80)  // Move text higher to clear buttons
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .ignoresSafeArea()
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
