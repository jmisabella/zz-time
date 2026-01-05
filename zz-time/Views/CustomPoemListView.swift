import SwiftUI

struct CustomPoemListView: View {
    @ObservedObject var manager: CustomPoemManager
    @Binding var isPresented: Bool
    let onPlay: (String) -> Void

    @State private var editingPoem: CustomPoem?
    @AppStorage("showMeditationText") private var showMeditationText: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if manager.poems.isEmpty {
                emptyStateView
            } else {
                poemList
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    // CC Toggle Button
                    Button {
                        showMeditationText.toggle()
                    } label: {
                        Image(systemName: "captions.bubble.fill")
                            .font(.title3)
                            .foregroundColor(showMeditationText ? Color.purple : Color(hex: 0x757575))
                    }

                    // Add Button
                    if manager.canAddMore {
                        Button {
                            editingPoem = CustomPoem(title: "", text: "")
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
        }
        .sheet(item: $editingPoem) { poem in
            CustomPoemEditorView(
                manager: manager,
                poem: poem,
                isPresented: Binding(
                    get: { editingPoem != nil },
                    set: { if !$0 { editingPoem = nil } }
                )
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "theatermasks")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("No Custom Poems")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Create your own poems with custom pauses and pacing")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                editingPoem = CustomPoem(title: "", text: "")
            } label: {
                Label("Create First Poem", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var poemList: some View {
        List {
            // Play Random button at the top
            if manager.poems.count > 1 {
                Button {
                    if let randomPoem = manager.poems.randomElement() {
                        onPlay(randomPoem.text)
                        isPresented = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "shuffle.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                        Text("Play Random Poem")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.purple.opacity(0.1))
            }

            ForEach(manager.poems) { poem in
                PoemRowView(
                    poem: poem,
                    onPlay: {
                        onPlay(poem.text)
                        isPresented = false
                    },
                    onEdit: {
                        editingPoem = poem
                    },
                    onDuplicate: {
                        manager.duplicatePoem(poem)
                    }
                )
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    manager.deletePoem(manager.poems[index])
                }
            }

            if manager.canAddMore {
                Button {
                    editingPoem = CustomPoem(title: "", text: "")
                } label: {
                    Label("Add New Poem", systemImage: "plus.circle")
                        .foregroundColor(.purple)
                }
            } else {
                Text("Maximum \(manager.poems.count) poems reached")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            }
        }
    }
}

struct PoemRowView: View {
    let poem: CustomPoem
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(poem.title.isEmpty ? "Untitled" : poem.title)
                    .font(.headline)

                Text(poem.text.prefix(60) + (poem.text.count > 60 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onDuplicate) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.title3)
                    .foregroundColor(.purple)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}
