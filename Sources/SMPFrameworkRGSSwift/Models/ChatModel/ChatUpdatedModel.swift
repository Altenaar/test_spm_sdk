//
//  MessageUpdatedModel.swift
//  DRsdk
//
//  Created by Артем Чурсин on 13.04.2021.
//

import Foundation

// MARK: - ChatObject
class ChatObject: Codable {
    let chatID: Int?
    let dateInsert, dateUpdate: String?
    let orderID: Int?
    let status: String?
    let employee: String?
    let unread: Int?
    let onlineStatusColor, onlineStatusText: String?
    let sort: Int?
    let empty: Bool?
    let statusMessage, statusMessageColor, name, photo: String?
    let title: String?
    let messageList: [HistoryChatMessage]?

    enum CodingKeys: String, CodingKey {
        case chatID = "chatId"
        case dateInsert, dateUpdate
        case orderID = "orderId"
        case status, employee, unread, onlineStatusColor, onlineStatusText, sort, empty, statusMessage, statusMessageColor, name, photo, title, messageList
    }

    init(chatID: Int?, dateInsert: String?, dateUpdate: String?, orderID: Int?, status: String?, employee: String?, unread: Int?, onlineStatusColor: String?, onlineStatusText: String?, sort: Int?, empty: Bool?, statusMessage: String?, statusMessageColor: String?, name: String?, photo: String?, title: String?, messageList: [HistoryChatMessage]?) {
        self.chatID = chatID
        self.dateInsert = dateInsert
        self.dateUpdate = dateUpdate
        self.orderID = orderID
        self.status = status
        self.employee = employee
        self.unread = unread
        self.onlineStatusColor = onlineStatusColor
        self.onlineStatusText = onlineStatusText
        self.sort = sort
        self.empty = empty
        self.statusMessage = statusMessage
        self.statusMessageColor = statusMessageColor
        self.name = name
        self.photo = photo
        self.title = title
        self.messageList = messageList
    }
}

enum ClientStatus: String, Codable {
    case new = "new"
    case read = "read"
}
