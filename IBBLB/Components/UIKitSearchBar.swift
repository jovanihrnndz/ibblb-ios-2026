//
//  UIKitSearchBar.swift
//  IBBLB
//
//  UIKit UISearchBar wrapper for true transparency matching tab bar
//

import SwiftUI

#if canImport(UIKit)
import UIKit

struct UIKitSearchBar: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "Search..."
    
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
        }
        
        // Set placeholder
        searchBar.placeholder = placeholder
        
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

#else

/// Android stub: native SwiftUI field until a platform-specific search control is added.
struct UIKitSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
    }
}

#endif

#if canImport(UIKit)
#Preview {
    UIKitSearchBar(text: .constant(""))
        .padding()
}
#endif
