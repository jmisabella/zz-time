import SwiftUI

struct StorySelectionView: View {
    let collections: [StoryCollection]
    @Binding var selectedCollectionID: UUID?
    @Binding var isPresented: Bool
    var onSelectionChanged: (() -> Void)?

    var body: some View {
        NavigationView {
            List(collections) { collection in
                Button {
                    let previousID = selectedCollectionID
                    selectedCollectionID = collection.id
                    isPresented = false

                    // Notify if selection actually changed
                    if previousID != collection.id {
                        onSelectionChanged?()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(collection.displayName)
                                .font(.headline)
                                .foregroundColor(.primary)

                            HStack(spacing: 12) {
                                Label("\(collection.storyFiles.count) chapters",
                                      systemImage: "book")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if !collection.poemFiles.isEmpty {
                                    Label("\(collection.poemFiles.count) poems",
                                          systemImage: "theatermasks")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        Spacer()

                        if selectedCollectionID == collection.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Select Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
