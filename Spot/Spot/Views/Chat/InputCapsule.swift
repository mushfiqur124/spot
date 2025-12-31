//
//  InputCapsule.swift
//  Spot
//
//  Floating pill-shaped text input field.
//  Uses warm glass material and floats above the bottom edge.
//

import SwiftUI

struct InputCapsule: View {
    @Binding var text: String
    let placeholder: String
    let onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: SpotTheme.Spacing.sm) {
            // Text field
            TextField(placeholder, text: $text, axis: .vertical)
                .font(SpotTheme.Typography.body)
                .foregroundStyle(SpotTheme.textPrimary)
                .lineLimit(1...5)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendIfNotEmpty()
                }
            
            // Send button
            sendButton
        }
        .padding(.horizontal, SpotTheme.Spacing.md)
        .padding(.vertical, SpotTheme.Spacing.sm)
        .warmGlass(style: .prominent, cornerRadius: SpotTheme.Radius.pill)
        .spotShadow(SpotTheme.Shadow.medium)
        .padding(.horizontal, SpotTheme.Spacing.md)
        .padding(.bottom, SpotTheme.Spacing.xs)
    }
    
    // MARK: - Send Button
    
    @ViewBuilder
    private var sendButton: some View {
        Button(action: sendIfNotEmpty) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(canSend ? SpotTheme.clay : SpotTheme.textSecondary)
        }
        .disabled(!canSend)
        .animation(.easeInOut(duration: 0.2), value: canSend)
    }
    
    // MARK: - Helpers
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func sendIfNotEmpty() {
        guard canSend else { return }
        onSend()
    }
}

// MARK: - Preview

#Preview("Input Capsule") {
    struct PreviewWrapper: View {
        @State private var text = ""
        
        var body: some View {
            ZStack {
                SpotTheme.canvas
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    InputCapsule(
                        text: $text,
                        placeholder: "Message Spot...",
                        onSend: {
                            print("Sent: \(text)")
                            text = ""
                        }
                    )
                }
            }
        }
    }
    
    return PreviewWrapper()
}

#Preview("Input Capsule - Dark") {
    struct PreviewWrapper: View {
        @State private var text = "Bench press 185 for 6"
        
        var body: some View {
            ZStack {
                SpotTheme.canvas
                    .ignoresSafeArea()
                
                VStack {
                    Spacer()
                    
                    InputCapsule(
                        text: $text,
                        placeholder: "Message Spot...",
                        onSend: {
                            print("Sent: \(text)")
                            text = ""
                        }
                    )
                }
            }
        }
    }
    
    return PreviewWrapper()
        .preferredColorScheme(.dark)
}

