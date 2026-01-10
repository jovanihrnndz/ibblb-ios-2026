//
//  SearchBar.swift
//  IBBLB
//
//  Custom search bar component with enhanced styling and interactions
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    
    @FocusState private var isFocused: Bool
    @State private var isEditing: Bool = false
    
    // Platform detection
    private var isTV: Bool {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }
    
    // Icon sizes - using semantic font sizes will handle Dynamic Type automatically
    private var iconSize: CGFloat {
        isTV ? 24 : 16
    }
    
    private var padding: CGFloat {
        isTV ? 20 : 14
    }
    
    private var verticalPadding: CGFloat {
        isTV ? 20 : 12
    }
    
    private var cornerRadius: CGFloat {
        isTV ? 20 : 12
    }
    
    var body: some View {
        HStack(spacing: isTV ? 20 : 12) {
            // Search icon - icon size is relatively fixed for UI consistency
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? .accentColor : .secondary)
                .font(.system(size: iconSize, weight: .medium))
                .animation(.easeInOut(duration: 0.2), value: isFocused)
                .accessibilityHidden(true)
            
            // Text field - uses Dynamic Type semantic font
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .foregroundColor(.primary)
                .font(isTV ? .title3 : .body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .accessibilityLabel("Search field")
                .accessibilityHint("Enter text to search")
                .onChange(of: isFocused) { oldValue, newValue in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isEditing = newValue
                    }
                }
            
            // Clear button with animation
            if !text.isEmpty {
                Button(action: {
                    #if !os(tvOS)
                    // Haptic feedback (not available on tvOS)
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                    #endif
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        text = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(isTV ? .title2 : .title3)
                }
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Clear search")
                .accessibilityHint("Double tap to clear the search text")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, padding)
        .padding(.vertical, verticalPadding)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    isFocused ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.1),
                    lineWidth: isFocused ? (isTV ? 2.5 : 1.5) : (isTV ? 1.0 : 0.5)
                )
        )
        .shadow(
            color: isFocused ? Color.black.opacity(0.2) : Color.black.opacity(0.08),
            radius: isFocused ? (isTV ? 12 : 10) : (isTV ? 8 : 6),
            x: 0,
            y: isFocused ? 4 : 2
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }
}

#Preview("Empty State") {
    SearchBar(text: .constant(""))
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("With Text") {
    SearchBar(text: .constant("Sample search text"))
        .padding()
        .background(Color(.systemGroupedBackground))
}
