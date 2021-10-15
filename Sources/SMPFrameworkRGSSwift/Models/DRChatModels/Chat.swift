//
//  Chat.swift
//  DRsdk
//
//  Created by Артем Чурсин on 01.04.2021.
//

import Foundation

class Chat: Decodable {
    enum ChatType: Int {
        case general = 0
        case smart
    }

    enum Status: String {
        case new = "new"
        case opened = "opened"
        case closed = "close"
        case active = "active"
        case inactive = "inactive"
        case awaiting = "awaiting"
        case sleeping = "sleeping"
        case inTheWork = "inTheWork"
    }

    enum Employee: String {
        case docOperator = "operator"
        case personalDoctor = "personalDoctor"
        case telemedDoctor = "telemedDoctor"
    }

    var id: Int64 = 0
    var title: String?
    var name: String?
    var image: String?
    var dateInsert: Date?
    var orderId: Int?
    var unreadMessagesCount: Int = 0
    var statusText: String?
    var statusColor: String?
    var statusMessage: String?
    var statusMessageColor: String?
    private var _status: String?
    private var _chatType: Int = 0
    var status: Status? {
        get {
            if let resolvedStatus = _status {
                return Chat.Status(rawValue: resolvedStatus)
            }
            return nil
        }
        set {
            _status = newValue?.rawValue
        }
    }
    var chatType: ChatType {
        get {
            if let type = Chat.ChatType(rawValue: _chatType) {
                return type
            }
            return .general
        }
        set {
            _chatType = newValue.rawValue
        }
    }
    private var _employee: String?
    var employee: Employee? {
        get {
            if let resolved = _employee {
                return Chat.Employee(rawValue: resolved)
            }
            return nil
        }
        set {
            _employee = newValue?.rawValue
        }
    }
    var sort: Int = 0
    var empty = false // true = has no personal doctor

    static func primaryKey() -> String? {
        return "id"
    }

    static func ignoredProperties() -> [String] {
        return [
            "status",
            "employee"
        ]
    }

    enum CodingKeys: String, CodingKey {
        case id = "chatId"
        case title
        case name
        case image = "photo"
        case dateInsert
        case orderId
        case unreadMessagesCount = "unread"
        case statusText = "onlineStatusText"
        case statusColor = "onlineStatusColor"
        case statusMessage
        case statusMessageColor
        case status
        case employee
        case sort
        case empty
    }

    /// Returns chat with current id or creates new one with id = 0. Also fills other chat parameters.
//    static func current() -> Chat {
//        let chat = Chat()
//        chat.id = Storage.currentChatId
//        chat.name = DocLocalizator.localizedString("operator", comment: "")
//        return chat
//    }

    var isPersonalDoctorSubscription: Bool {
        return employee == .personalDoctor && empty
    }

    /// Duplicates object with no connection to Realm.
//    func selfCopy() -> Chat {
//        return Chat(value: self)
//    }

    // MARK: Decodable
    convenience required init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id) // required
        if let title = try container.decodeIfPresent(String.self, forKey: .title),
            !title.isEmpty {
            self.title = title
        }
        if let name = try container.decodeIfPresent(String.self, forKey: .name),
            !name.isEmpty {
            self.name = name
        }
        image = try container.decodeIfPresent(String.self, forKey: .image)
        if let dateString = try container.decodeIfPresent(String.self, forKey: .dateInsert) {
            dateInsert = DateFormatter.doc_dateTimeWithSecondsFormat().date(from: dateString)
        }
        orderId = try container.decodeIfPresent(Int.self, forKey: .orderId)
        if let unread = try container.decodeIfPresent(Int.self, forKey: .unreadMessagesCount) {
            unreadMessagesCount = unread
        }
        statusText = try container.decodeIfPresent(String.self, forKey: .statusText)
        statusColor = try container.decodeIfPresent(String.self, forKey: .statusColor)
        if let statusMessage = try container.decodeIfPresent(String.self, forKey: .statusMessage),
            !statusMessage.isEmpty {
            self.statusMessage = statusMessage
        }
        if let statusMessageColor = try container.decodeIfPresent(String.self, forKey: .statusMessageColor),
            !statusMessageColor.isEmpty {
            self.statusMessageColor = statusMessageColor
        }
        if let statusString = try container.decodeIfPresent(String.self, forKey: .status),
            let status = Chat.Status(rawValue: statusString) {
            self.status = status
        }
        if let employeeString = try container.decodeIfPresent(String.self, forKey: .employee),
            let employee = Chat.Employee(rawValue: employeeString) {
            self.employee = employee
        }
        if let sort = try container.decodeIfPresent(Int.self, forKey: .sort) {
            self.sort = sort
        }
        if let empty = try container.decodeIfPresent(Bool.self, forKey: .empty) {
            self.empty = empty
        }
    }
}
