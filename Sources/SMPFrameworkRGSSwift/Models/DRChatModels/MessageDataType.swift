//
//  MessageDataType.swift
//  DRsdk
//
//  Created by Артем Чурсин on 01.04.2021.
//

import Foundation

enum MessageDataType: Int {
    case message = 0
    case image = 1
    case doc = 2
    case excel = 3
    case pdf = 4
    case dicom = 5
    case pages = 6
    case numbers = 7

    case unknown = 10
    /// Local type for doctor info cell.
    case doctor = 20
    /// Local type for button cell.
    case button = 30

    init?(from fileName: String) {
        guard let lastPathComponent = fileName.components(separatedBy: ".").last?.lowercased() else { return nil }
        switch lastPathComponent {
        case "pages":
            self = .pages
        case "numbers":
            self = .numbers
        case "dcm", "dicom":
            self = .dicom
        case "doc", "docx":
            self = .doc
        case "xls", "xlsx", "xlsm":
            self = .excel
        case "pdf":
            self = .pdf
        case "png", "jpeg", "jpg":
            self = .image
        default:
            return nil
        }
    }
}
