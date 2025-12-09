import SwiftUI

struct CustomMeditationListView: View {
    @ObservedObject var manager: CustomMeditationManager
    @Binding var isPresented: Bool
    let onPlay: (String) -> Void

    @State private var editingMeditation: CustomMeditation?
    @AppStorage("showMeditationText") private var showMeditationText: Bool = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if manager.meditations.isEmpty {
                    emptyStateView
                } else {
                    meditationList
                }
            }
            .navigationTitle("Custom Meditations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 16) {
                        // CC Toggle Button
                        Button {
                            showMeditationText.toggle()
                        } label: {
                            Image(systemName: "captions.bubble.fill")
                                .font(.title3)
                                .foregroundColor(showMeditationText ? Color(hex: 0x64B5F6) : Color(hex: 0x757575))
                        }

                        // Add Button
                        if manager.canAddMore {
                            Button {
                                editingMeditation = CustomMeditation(title: "", text: "")
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                            }
                        }
                    }
                }
            }
            .sheet(item: $editingMeditation) { meditation in
                CustomMeditationEditorView(
                    manager: manager,
                    meditation: meditation,
                    isPresented: $editingMeditation
                )
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "text.quote")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Custom Meditations")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("Create your own guided meditation with custom pauses and pacing")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                editingMeditation = CustomMeditation(title: "", text: "")
            } label: {
                Label("Create First Meditation", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var meditationList: some View {
        List {
            // Play Random button at the top
            if manager.meditations.count > 1 {
                Button {
                    if let randomMeditation = manager.meditations.randomElement() {
                        onPlay(randomMeditation.text)
                        isPresented = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "shuffle.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                        Text("Play Random Meditation")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.purple.opacity(0.1))
            }

            ForEach(manager.meditations) { meditation in
                MeditationRowView(
                    meditation: meditation,
                    onPlay: {
                        onPlay(meditation.text)
                        isPresented = false
                    },
                    onEdit: {
                        editingMeditation = meditation
                    },
                    onDuplicate: {
                        manager.duplicateMeditation(meditation)
                    }
                )
            }
            .onDelete { indexSet in
                indexSet.forEach { index in
                    manager.deleteMeditation(manager.meditations[index])
                }
            }
            
            if manager.canAddMore {
                Button {
                    editingMeditation = CustomMeditation(title: "", text: "")
                } label: {
                    Label("Add New Meditation", systemImage: "plus.circle")
                        .foregroundColor(.blue)
                }
            } else {
                Text("Maximum \(manager.meditations.count) meditations reached")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .listRowBackground(Color.clear)
            }
        }
    }
}

struct MeditationRowView: View {
    let meditation: CustomMeditation
    let onPlay: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meditation.title.isEmpty ? "Untitled" : meditation.title)
                    .font(.headline)
                
                Text(meditation.text.prefix(60) + (meditation.text.count > 60 ? "..." : ""))
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
