//
//  CustomPoemEditorView.swift
//  zz-time
//


import SwiftUI

struct CustomPoemEditorView: View {
    @ObservedObject var manager: CustomPoemManager
    let poem: CustomPoem
    @Binding var isPresented: Bool

    @State private var title: String = ""
    @State private var text: String = ""

    init(manager: CustomPoemManager, poem: CustomPoem, isPresented: Binding<Bool>) {
        self.manager = manager
        self.poem = poem
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
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(4)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Title Field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Title")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Poem title", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)

                    // Text Editor
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Poem Text")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextEditor(text: $text)
                            .font(.body)
                            .scrollContentBackground(.hidden)  // Hide default background
                            .background(Color(UIColor.secondarySystemGroupedBackground))  // Adaptive background
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                            .frame(minHeight: 200, maxHeight: 400)  // Give it a minimum and maximum height
                    }
                    .padding(.horizontal)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                // Initialize state when view appears
                title = poem.title
                text = poem.text
            }
            .navigationTitle(poem.title.isEmpty ? "New Poem" : "Edit Poem")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        let updatedPoem = CustomPoem(
                            id: poem.id,
                            title: title.isEmpty ? "Untitled" : title,
                            text: text,
                            dateCreated: poem.dateCreated
                        )

                        if manager.poems.contains(where: { $0.id == poem.id }) {
                            manager.updatePoem(updatedPoem)
                        } else {
                            manager.addPoem(updatedPoem)
                        }

                        isPresented = false
                    }
                    .disabled(text.isEmpty)
                }
            }
        }
    }
            }
