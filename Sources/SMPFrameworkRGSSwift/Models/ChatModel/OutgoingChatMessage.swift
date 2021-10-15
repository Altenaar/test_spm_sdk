//
//  OutgoingChatMessage.swift
//  DRsdk
//
//  Created by Артем Чурсин on 24.03.2021.
//

import Foundation

/**
 * Класс, определяющий сообщение, отправляемое в чат
 * - version:
 * 1.0.0
 */
public class OutgoingChatMessage {
    
    public let text: String?
    let file: OutgoingMessageFile?
    
    ///Уникальный ID сообщения
    public let uniqueId: String
    
    /// Создание отправляемого сообщения для чата
    ///
    /// - parameter text:   текст сообщения. Может быть null, если сообщеение не является текстовым
    /// - parameter file:   описание файла, приложенного к сообщению. Может быть null
    public init(text: String?, file: OutgoingMessageFile?) {
        
        self.text = text
        self.file = file
        self.uniqueId = UUID().uuidString
    }
    
    func JSONParams() -> [String: Any] {
        var params = [String: Any]()
        params["data"] = messageJSONParams()
        params["uniqueId"] = uniqueId
        return params
    }
    
    func typingParametrs(isTyping: Bool) -> [String: Any] {
        var params = [String: Any]()
        params["data"] = typingJSONParams(isTyping: isTyping)
        return params
    }
    
    private func typingJSONParams(isTyping: Bool) -> [String: Any] {
        var params = [String: Any]()
        params["status"] = isTyping ? "started" : "stopped"
        params["type"] = "typing2"
        return params
    }
    
    
    private func messageJSONParams() -> [String: Any] {
        var params = [String: Any]()
        params["message"] = text
        params["messageId"] = ""
        params["type"] = "message"
        return params
    }
}
