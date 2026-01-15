import SwiftUI

struct ContentBrowserView: View {
    @ObservedObject var storyManager: CustomStoryManager
    @ObservedObject var poemManager: CustomPoemManager
    @Binding var isPresented: Bool
    let onPlayStory: (String) -> Void
    let onPlayPoem: (String) -> Void

    @State private var selectedTab = 0  // 0 = Stories, 1 = Poems

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("Content Type", selection: $selectedTab) {
                    Text("Stories").tag(0)
                    Text("Poems").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                // Content based on selected tab
                if selectedTab == 0 {
                    CustomStoryListView(
                        manager: storyManager,
                        isPresented: $isPresented,
                        onPlay: onPlayStory
                    )
                } else {
                    CustomPoemListView(
                        manager: poemManager,
                        isPresented: $isPresented,
                        onPlay: onPlayPoem
                    )
                }
            }
            .navigationTitle("My Content")
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
