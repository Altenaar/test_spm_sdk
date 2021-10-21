//
//  ChatModuleImp.swift
//  DRsdk
//
//  Source code
//

import Foundation

class ChatModuleImp: ChatModule {
    
    private var requestManager: RequestManagerProtocol = RequestManager(host: "https://telemed-dr.ru/api/v1/", token: "", userToken: "")
    private var orderService: OrderServiceProtocol?
    private var chatService: ChatServiceProtocol?
    private var consultation: ConsultationInformationObject?
    private var chatId: Int?
    
    var onOpponentOnlineStatusChangeSubject: ((OpponentOnlineStatus) -> Void)?
    var onOpponentWritingStatusChangeSubject: ((OpponentWritingStatus) -> Void)?
    private var writingStatus: OpponentWritingStatus = .notWriting {
        didSet {
            onOpponentWritingStatusChangeSubject?(writingStatus)
        }
    }
    private var onlineStatus: OpponentOnlineStatus = .offline {
        didSet {
            onOpponentOnlineStatusChangeSubject?(onlineStatus)
        }
    }
    
    var chatHistory = [HistoryChatMessage]()
    var webSocketChatService: WebSocketChatServiceProtocol?
    var onMessage: ((HistoryChatMessage?) -> Void)?
    
    func create(consultationId: String,
                token: String,
                userToken: String,
                complete: ((_ complete: Bool, _ error: Error?) -> Void)?) {
        requestManager = RequestManager(host: "https://telemed-dr.ru/api/v1/", token: token , userToken: userToken)
        
        orderService = OrderService(requestManager: requestManager)
        chatService = ChatService(requestManager: requestManager, chatParser: ChatParser())
        
        self.getOrder(id: consultationId) { (success, error) in
            if success  {
                complete?(true, nil)
            } else {
                complete?(false, CommonError.customError(error ?? "Unknown error"))
            }
        }
    }
    
    func destroy() {
        webSocketChatService?.disconnect()
    }
    
    func sendMessage(message: OutgoingChatMessage) {
        if let file = message.file {
            let components = message.file?.originalFileName.components(separatedBy: ".")
            let pathExtension = components?.last ?? ""
            
            chatService?.sendFile(file.fileBase64,
                                  fileName: file.originalFileName,
                                  format: pathExtension,
                                  chatId: chatId ?? 0,
                                  messageId: message.uniqueId,
                                  messageParams: [:],
                                  completion: { (result, json) in
                                    print(result)
                                  })
        }
         webSocketChatService?.send(message: WebSocketMessage(jsonParams: message.JSONParams(), type: .message))
    }
    
    func isUserTyping(_ isTyping: Bool) {
        webSocketChatService?.send(message: WebSocketMessage(jsonParams: typingParams(isTyping: isTyping), type: .typing))
    }
    
    func getLastKnownOpponentWritingStatus() -> OpponentWritingStatus {
        return writingStatus
    }
    
    func getOpponentOnlineStatus() -> OpponentOnlineStatus {
        return onlineStatus
    }
    
    func loadChatHistory(lastMessageId: String? = nil,
                         maxMessages: Int = 100,
                         _ action: (([HistoryChatMessage], Error?) -> Void)?) {
        self.getMessages(chatID: self.chatId ?? 0, limit: maxMessages) { [weak self] (success, error) in
            if success  {
                action?(self?.chatHistory ?? [], nil)
            } else {
                action?([], CommonError.customError(error ?? "Unknown error"))
            }
        }
    }
    
    private func typingParams(isTyping: Bool) -> [String: Any] {
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
}

//MARK: - API
private extension ChatModuleImp {
    private func getOrder(id: String, _ action: ((Bool, String?) -> Void)?)  {
        orderService?.getOrder(id: id) { [weak self] (error, order) in
            if let order = order {
                self?.consultation = order
                if let chatId = order.chatId {
                    self?.chatId = chatId
                    self?.getJWTToken(chatId: chatId, action)
                } else {
                    action?(false, "Get order error, dont have chatID in order")
                }
            } else if let error = error, let drError = error as? RequestManagerError {
                print("\(drError.message)")
                action?(false, drError.message)
            } else {
                action?(false, "Get order unknown error")
            }
        }
    }
    
    private func getJWTToken(chatId: Int, _ action: ((Bool, String?) -> Void)?) {
        chatService?.getJWTToken(chatId, completion: { [weak self] (questionId, token) in
            guard let self = self else {
                action?(false, "Get token error")
                return
            }
            if let t  = token {
                self.webSocketChatService = WebSocketChatService("telemed-dr.ru",
                                                            chatId: "\(chatId)",
                                                            token: t)
                self.webSocketChatService?.onMessage = { [weak self] message in
                    self?.onMessage?(message)
                }
                
                self.webSocketChatService?.onTyping = { [weak self] (isTyping, text) in
                    let status: OpponentWritingStatus = isTyping ? .writing : .notWriting
                    self?.writingStatus = status
                }
                
                self.webSocketChatService?.onChatStatusChange = { [weak self] onStatus, _ in
                    guard let status = onStatus else {
                        return
                    }
                    var sdkStatus: OpponentOnlineStatus = .offline
                    switch status {
                    case .active:
                        sdkStatus = .online
                    case .inactive:
                        sdkStatus = .offline
                    case .awaiting:
                        sdkStatus = .away
                    default:
                        break
                    }
                    self?.onlineStatus = sdkStatus
//                    self?.onOpponentOnlineStatusChangeSubject.on(.next(sdkStatus))
                }
                
                self.webSocketChatService?.connect()
                self.getMessages(chatID: chatId, limit: 20, action)
            } else {
                action?(false, "Get token error")
            }
        })
    }
    
    private func getMessages(chatID: Int, limit: Int, _ action: ((Bool, String?) -> Void)?) {
        _ = chatService?.getMessagesList(chatID: Int64(chatID),
                                     limit: 20,
                                     completionBlock: { [weak self] chat, error in
            if let error = error {
                action?(false, error.localizedDescription)
            } else {
                self?.chatHistory = chat?.messageList ?? []
                action?(true, nil)
            }
        })
    }
}
