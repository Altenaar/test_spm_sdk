//
//  ChatParser.swift
//  DRsdk
//
//  Source code
//

import Foundation
import SwiftyJSON

protocol ChatParserProtocol {
    func parseData(_ data: JSON) throws -> Chat
}

class ChatParser: ChatParserProtocol {
    func parseData(_ data: JSON) throws -> Chat {
        // NOTE: Chat is Codable now. Any manual parsing for Chat objects is deprecated.
        let decoder = JSONDecoder()
        let jsonData = try data.rawData()
        return try decoder.decode(Chat.self, from: jsonData)
    }
}
