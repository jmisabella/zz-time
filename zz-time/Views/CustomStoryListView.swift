import SwiftUI

struct CustomStoryListView: View {
    @ObservedObject var manager: CustomStoryManager
    @Binding var isPresented: Bool
    let onPlay: (String) -> Void

    @State private var editingStory: CustomStory?
    @AppStorage("showStoryText") private var showStoryText: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            if manager.stories.isEmpty {
                emptyStateView
            } else {
                storyList
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    // CC Toggle Button
                    Button {
                        showStoryText.toggle()
                    } label: {
                        Image(systemName: "captions.bubble.fill")
                            .font(.title3)
                            .foregroundColor(showStoryText ? Color(hex: 0x64B5F6) : Color(hex: 0x757575))
                    }

                    // Add Button
                    if manager.canAddMore {
                        Button {
                            editingStory = CustomStory(title: "", text: "")
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                    }
                }
            }
        }
        .sheet(item: $editingStory) { story in
            CustomStoryEditorView(
                manager: manager,
                story: story,
                isPresented: $editingStory
            )
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.quote")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Custom Storys")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Create your own guided story with custom pauses and pacing")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                editingStory = CustomStory(title: "", text: "")
            } label: {
                Label("Create First Story", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var storyList: some View {
        List {
            // Play Random button at the top
            if manager.stories.count > 1 {
                Button {
                    if let randomStory = manager.stories.randomElement() {
                        onPlay(randomStory.text)
                        isPresented = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "shuffle.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                        Text("Play Random Story")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.purple.opacity(0.1))
            }

            ForEach(manager.stories) { story in
                StoryRowView(
                    story: story,
                    onPlay: {
                        onPlay(story.text)
                        isPresented = false
                    },
                    onEdit: {
                        editingStory = story
                    },
                    onDuplicate: {
                        manager.duplicateStory(story)
                    }
                )
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    manager.deleteStory(manager.stories[index])
                }
            }
            
            if manager.canAddMore {
                Button {
                    editingStory = CustomStory(title: "", text: "")
                } label: {
                    Label("Add New Story", systemImage: "plus.circle")
                        .foregroundColor(.blue)
                }
            } else {
                Text("Maximum \(manager.stories.count) storys reached")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            }
        }
    }
}

struct StoryRowView: View {
    let story: CustomStory
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(story.title.isEmpty ? "Untitled" : story.title)
                    .font(.headline)
                
                Text(story.text.prefix(60) + (story.text.count > 60 ? "..." : ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button(action: onDuplicate) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
    }
}
