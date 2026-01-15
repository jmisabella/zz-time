//
//  CustomStoryEditorView.swift
//  zz-time
//
//  Created by Jeffrey Isabella on 12/5/25.
//


import SwiftUI

struct CustomStoryEditorView: View {
    @ObservedObject var manager: CustomStoryManager
    let story: CustomStory
    @Binding var isPresented: CustomStory?
    
    @State private var title: String = ""
    @State private var text: String = ""

    init(manager: CustomStoryManager, story: CustomStory, isPresented: Binding<CustomStory?>) {
        self.manager = manager
        self.story = story
        self._isPresented = isPresented
        // Don't initialize @State in init - use onAppear instead
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Instructions
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add pauses: (3s) for seconds or (1m) for minutes after any word.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Example: \"Take a deep breath in. (3s)\"")
                            .font(.caption)
                            .italic()
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Title Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Story title", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)

                    // Text Editor
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Story Text")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextEditor(text: $text)
                            .font(.body)
                            .scrollContentBackground(.hidden)  // Hide default background
                            .background(Color(UIColor.secondarySystemGroupedBackground))  // Adaptive background
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .frame(minHeight: 200, maxHeight: 400)  // Give it a minimum and maximum height
                    }
                    .padding(.horizontal)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                // Initialize state when view appears
                title = story.title
                text = story.text
            }
            .navigationTitle(story.title.isEmpty ? "New Story" : "Edit Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = nil
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        let updatedStory = CustomStory(
                            id: story.id,
                            title: title.isEmpty ? "Untitled" : title,
                            text: text,
                            dateCreated: story.dateCreated
                        )

                        if manager.stories.contains(where: { $0.id == story.id }) {
                            manager.updateStory(updatedStory)
                        } else {
                            manager.addStory(updatedStory)
                        }

                        isPresented = nil
                    }
                    .disabled(text.isEmpty)
                }
            }
        }
    }
            }
