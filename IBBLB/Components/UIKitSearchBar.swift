//
//  UIKitSearchBar.swift
//  IBBLB
//
//  UIKit UISearchBar wrapper for true transparency matching tab bar
//

import SwiftUI
import UIKit

struct UIKitSearchBar: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = String(localized: "Search...")
    
    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.delegate = context.coordinator
        
        // Key settings for transparency
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundImage = UIImage()
        searchBar.scopeBarBackgroundImage = UIImage()
        searchBar.barTintColor = .clear
        searchBar.isTranslucent = true
        
        // Make text field transparent (iOS 13+)
        if #available(iOS 13.0, *) {
            searchBar.searchTextField.backgroundColor = .clear
            // Accessibility configuration
            searchBar.searchTextField.accessibilityLabel = "Search field"
            searchBar.searchTextField.accessibilityHint = "Enter text to search"
        }
        
        // Set placeholder
        searchBar.placeholder = placeholder
        
        // Configure accessibility
        searchBar.accessibilityLabel = "Search sermons"
        searchBar.accessibilityHint = "Enter text to search for sermons by title, speaker, or topic"
        
        return searchBar
    }
    
    func updateUIView(_ searchBar: UISearchBar, context: Context) {
        searchBar.text = text
        searchBar.placeholder = placeholder
        
        // Ensure transparency is maintained on updates
        if #available(iOS 13.0, *) {
            searchBar.searchTextField.backgroundColor = .clear
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UISearchBarDelegate {
        var parent: UIKitSearchBar
        
        init(_ parent: UIKitSearchBar) {
            self.parent = parent
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            parent.text = searchText
        }
        
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }
}

#Preview {
    UIKitSearchBar(text: .constant(""))
        .padding()
        .background(Color(.systemGroupedBackground))
}

