//
//  CustomMeditationEditorView.swift
//  zz-time
//
//  Created by Jeffrey Isabella on 12/5/25.
//


import SwiftUI

struct CustomMeditationEditorView: View {
    @ObservedObject var manager: CustomMeditationManager
    let meditation: CustomMeditation
    @Binding var isPresented: CustomMeditation?
    
    @State private var title: String = ""
    @State private var text: String = ""

    init(manager: CustomMeditationManager, meditation: CustomMeditation, isPresented: Binding<CustomMeditation?>) {
        self.manager = manager
        self.meditation = meditation
        self._isPresented = isPresented
        // Don't initialize @State in init - use onAppear instead
    }
    
    var body: some View {
        NavigationView {
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
                    
                    TextField("Meditation title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // Text Editor
                VStack(alignment: .leading, spacing: 4) {
                    Text("Meditation Text")
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
                        .frame(minHeight: 200)  // Give it a minimum height
                }
                .padding(.horizontal)
                
                Spacer()
                
                Button("Save") {
                    let updatedMeditation = CustomMeditation(
                        id: meditation.id,
                        title: title.isEmpty ? "Untitled" : title,
                        text: text,
                        dateCreated: meditation.dateCreated
                    )
                    
                    if manager.meditations.contains(where: { $0.id == meditation.id }) {
                        manager.updateMeditation(updatedMeditation)
                    } else {
                        manager.addMeditation(updatedMeditation)
                    }
                    
                    isPresented = nil
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(text.isEmpty ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                .padding(.horizontal)
                .disabled(text.isEmpty)
            }
                        .onAppear {
                            // Initialize state when view appears
                            title = meditation.title
                            text = meditation.text
                        }
                        .navigationTitle(meditation.title.isEmpty ? "New Meditation" : "Edit Meditation")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    isPresented = nil
                                }
                            }
                        }
                    }
                }
            }
