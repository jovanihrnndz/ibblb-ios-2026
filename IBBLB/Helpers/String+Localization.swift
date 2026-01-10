//
//  String+Localization.swift
//  IBBLB
//
//  Helper extension for easier localization usage
//

import Foundation

extension String {
    /// Returns a localized string using the String Catalog
    func localized() -> String {
        String(localized: String.LocalizationValue(self))
    }
    
    /// Returns a localized string with arguments
    func localized(_ arguments: CVarArg...) -> String {
        let format = String(localized: String.LocalizationValue(self))
        return String(format: format, locale: Locale.current, arguments: arguments)
    }
}
