//
//  WebSocketMessage.swift
//  DRsdk
//
//  Source code
//

import SwiftyJSON

struct WebSocketMessage {
    var type: MessageType
    fileprivate var json: JSON
    var error: Error?

    enum MessageType: String {
        case typing = "typing2"
        case message = "message"
        case serviceMessage = "service"
        case messageStatus = "status"
        case chatStatus = "chatStatus"
    }

    init?(jsonDict: [String: Any]) {
        guard let type = jsonDict["type"] as? String,
            let messageType = WebSocketMessage.MessageType(rawValue: type),
            let dataDict = jsonDict["data"] as? [String: Any] else {
                return nil
        }
        self.type = messageType
        self.json = JSON(dataDict)
    }

    init(jsonParams: [String: Any], type: MessageType) {
        self.type = type
        self.json = JSON(jsonParams)
    }
}

extension WebSocketMessage {
    func typingData() -> (userId: String, isTyping: Bool)? {
        guard let userId = json["message"]["userId"].string else { return nil }
        let isTyping = json["message"]["status"].string != "stopped"
        return (userId, isTyping)
    }

    func messageData() -> JSON {
        return json["message"]["data"]
    }

    func messageStatusData() -> (messageId: String, status: Message.Status)? {
        guard let messageId = json["message"]["data"]["messageId"].string,
            let statusString = json["message"]["data"]["status"].string,
            let status = Message.Status(rawValue: statusString) else {
                return nil
        }
        return (messageId, status)
    }

    func chatStatusData() -> (status: Chat.Status?, statusText: String)? {
        guard let statusString = json["message"]["status"].string,
            let statusText = json["message"]["statusText"].string else {
                return nil
        }
        return (Chat.Status(rawValue: statusString), statusText)
    }
}

extension WebSocketMessage {
    func stringParameters() -> String? {
        let dataDict = json.dictionaryObject
        return JSON(dataDict ?? [:]).rawString(.utf8, options: .prettyPrinted)
    }
}

