//
//  ChatService.swift
//  DRsdk
//
//  Source code
//

import Foundation
import Alamofire
import SwiftyJSON

enum MessagesDirection: Int {
    /// From elder to newer.
    case forward = 1
    /// From newer to elder (e.g., paginated history).
    case backward = -1
}

protocol ChatServiceProtocol: ServiceProtocol {
    //    /user/files/chat/{id}/attach
    func sentLocalFiles(_ chatId: Int, _ files: [Int], completion: @escaping (Error?) -> Void)
    
    func sendFile(_ data: String, fileName: String, format: String, chatId: Int, messageId: String, messageParams: [String: Any], completion: @escaping (Bool, JSON?) -> Void)
    func getJWTToken(_ chatId: Int, completion: @escaping (Int, String?) -> Void)
    @discardableResult func fetchChatListWith(_ isOpened: Bool, completionBlock:@escaping ([Chat]?, Error?) -> Void) -> Alamofire.Request?
    @discardableResult func getMessagesList(chatID: Int64,
                                            limit: Int?,
                                            completionBlock: @escaping (ChatObject?, Error?) -> Void) -> Alamofire.Request?
}

class ChatService {
    var requestManager: RequestManagerProtocol
    private let chatParser: ChatParserProtocol
    
    fileprivate let kChatPath = "chat/"
    fileprivate let kMessagePath = "message/"
    
    init(requestManager: RequestManagerProtocol, chatParser: ChatParserProtocol) {
        self.requestManager = requestManager
        self.chatParser = chatParser
    }
}

extension ChatService: ChatServiceProtocol {
    
    //    /user/files/chat/{id}/attach
    func sentLocalFiles(_ chatId: Int, _ files: [Int], completion: @escaping (Error?) -> Void) {
        var finalParams: [String: Any] = ["": ""]
        finalParams["filesIds"] = files
        _ = requestManager.makePostRequest("user/files/chat/\(chatId)/attach", parameters: finalParams as [String : AnyObject], completedBlock: {
            switch $0 {
            case .success(let json):
                print("complete LocalFiles \(json)")
                completion(nil)
            case .failure(let error):
                completion(error)
            }
        })
    }
    
    func getJWTToken(_ chatId: Int, completion: @escaping (Int, String?) -> Void) {
        var finalParams: [String: Any] = ["": ""]
        finalParams["chatId"] = chatId as AnyObject
        _ = requestManager.makeGetRequest("\(kChatPath)token", parameters: finalParams as [String : AnyObject], completedBlock: {
            switch $0 {
            case .success(let json):
                print("getJWTToken \(json)")
                completion(json["data"]["questionId"].int ?? 0, json["data"]["token"].stringValue)
            case .failure:
                completion(0, nil)
            }
        })
    }
    
    func sendFile(_ data: String, fileName: String, format: String, chatId: Int, messageId: String, messageParams: [String: Any], completion: @escaping (Bool, JSON?) -> Void) {
        var params = messageParams
        params["original_name"] = Date().toString(format: "dd.MM.yyyy.hh.mm.ss") + fileName
        params["message"] = fileName
//        params["format"] = format
        params["base64"] = data
        params["chatId"] = chatId
        params["messageId"] = messageId
        _ = requestManager.makePostRequest("\(kChatPath)message/photo", parameters: params as [String : AnyObject], completedBlock: {
            switch $0 {
            case .success(let json):
                print(json)
                completion(true, json)
            //                print("getJWTToken \(json)")
            //              completion(json["data"]["questionId"].int ?? 0, json["data"]["token"].stringValue)
            case .failure:
                completion(false, nil)
            }
        })
    }
    
    func fetchChatListWith(_ isOpened: Bool,
                           completionBlock: @escaping ([Chat]?, Error?) -> Void) -> Alamofire.Request? {
        let parameters = ["isOpened": isOpened]
        return requestManager.makeGetRequest("\(kChatPath)list/2", keyPath: nil, parameters: parameters, completion: { [weak self] (result: CodableRequestResult<[Chat]>) in
            guard let _ = self else { return }
            switch result {
            case .success(let data):
                print("fetchChatListWith \(data)")
                completionBlock(data, nil)
            case .failure(let error):
                completionBlock(nil, error)
            }
        })
    }
    
    func getMessagesList(chatID: Int64,
                         limit: Int? = 20,
                         completionBlock: @escaping (ChatObject?, Error?) -> Void) -> Alamofire.Request? {
        var finalParams: [String: Any] = [:]
        finalParams["chatId"] = chatID
        finalParams["active"] = "true" // send as String
        if let limit = limit {
            finalParams["limit"] = limit
        }
        return requestManager.makeGetRequest("\(self.kChatPath)\(self.kMessagePath)get-list-paginated/2",
                                             keyPath: nil,
                                             parameters: finalParams as [String: AnyObject],
                                             completion: { [weak self] (result: CodableRequestResult<ChatObject?>) in
            guard let _ = self else { return }
            switch result {
            case .success(let data):
                print("fetchChatListWith \(String(describing: data))")
                completionBlock(data, nil)
            case .failure(let error):
                completionBlock(nil, error)
            }
        })
    }
}

