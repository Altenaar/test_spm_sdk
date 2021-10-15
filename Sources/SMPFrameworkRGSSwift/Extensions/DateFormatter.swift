//
//  DateFormatter.swift
//  DRsdk
//
//  Created by Артем Чурсин on 01.04.2021.
//

import Foundation

extension DateFormatter {
    
    static private func localeIdentifier() -> String {
        return "ru"
    }
    
    static func doc_dateTimeWithSecondsFormat() -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: localeIdentifier())
        dateFormatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        return dateFormatter
    }
}

extension Date {
    func toString(format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        dateFormatter.locale = Locale(identifier: "ru")
        return dateFormatter.string(from: self)
    }
}
