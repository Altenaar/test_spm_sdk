//
//  HistoryChatMessage.swift
//  DRsdk
//
//  Created by Артем Чурсин on 24.03.2021.
//

import Foundation

// MARK: - MessageList
public class HistoryChatMessage: Codable {
    
    // MARK: - Public
    public let id: Int?
    public let message, serviceMessage: String?
    public let name: String?
    public let messageID: String?
    public let userType: String?
    
    // MARK: - Internal
    let timestamp, dateInsert, realMessageID: String?
    let chatID: Int?
    let image: String?
    let userPhoto: String?
    let userID: Int?
    let answerType: String?
    let status: String?
    let clientStatus: String?
    let file: File?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, dateInsert
        case messageID = "messageId"
        case realMessageID = "realMessageId"
        case chatID = "chatId"
        case message, serviceMessage, image, userPhoto, name, userType
        case userID = "userId"
        case clientStatus, file
        case status, answerType
    }

    init(id: Int?, timestamp: String?, dateInsert: String?, messageID: String?, realMessageID: String?, chatID: Int?, message: String?, serviceMessage: String?, userType: String?, name: String?, image: String?, userPhoto: String?, userID: Int?, answerType: String?, status: String?, clientStatus: String?, file: File?) {
        self.id = id
        self.timestamp = timestamp
        self.dateInsert = dateInsert
        self.messageID = messageID
        self.realMessageID = realMessageID
        self.chatID = chatID
        self.message = message
        self.serviceMessage = serviceMessage
        self.userType = userType
        self.name = name
        self.image = image
        self.userPhoto = userPhoto
        self.userID = userID
        self.answerType = answerType
        self.status = status
        self.clientStatus = clientStatus
        self.file = file
    }
}

// MARK: - File
class File: Codable {
    let path, pathBase64: String?
    let mime: String?
    let thumbnail, thumbnailBase64: String?
    let name, fileType: String?

    init(path: String?, pathBase64: String?, mime: String?, thumbnail: String?, thumbnailBase64: String?, name: String?, fileType: String?) {
        self.path = path
        self.pathBase64 = pathBase64
        self.mime = mime
        self.thumbnail = thumbnail
        self.thumbnailBase64 = thumbnailBase64
        self.name = name
        self.fileType = fileType
    }
}
