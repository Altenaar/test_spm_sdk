//
//  WebSocketChatService.swift
//  DRsdk
//
//  Source code
//

import Starscream
import Foundation

protocol WebSocketChatServiceProtocol {
    func connect()
    func disconnect()
    func send(message: String)
    func send(message: WebSocketMessage)
    func refresh(_ token: String)
    var isConnected: Bool { get }

    /// Socket connected.
    var onConnect: (() -> Void)? { get set }
    /// Socket disconnected.
    var onDisconnect: (() -> Void)? { get set }
    /// Correspondent is typing.
    var onTyping: ((Bool, String?) -> Void)? { get set }
    /// Message received.
    var onMessage: ((HistoryChatMessage?) -> Void)? { get set }
    /// Message status changed.
    var onMessageStatusChange: ((String, Message.Status) -> Void)? { get set }
    /// Chat status changed.
    var onChatStatusChange: ((Chat.Status?, String) -> Void)? { get set }
}

class WebSocketChatService: NSObject {

    fileprivate let host: String
    fileprivate let typingDelay: TimeInterval = 5

    fileprivate var socket: WebSocket?

    fileprivate var chatId: String
    fileprivate var token: String?

    /// The number of times the socket has been retried to connect.
    fileprivate var retryCount: UInt = 0
    fileprivate let maxRetryCount: UInt = 5
    fileprivate let retryDelay: TimeInterval = 5

    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?
    var onMessage: ((HistoryChatMessage?) -> Void)?
    var onTyping: ((Bool, String?) -> Void)?
    var onMessageStatusChange: ((String, Message.Status) -> Void)?
    var onChatStatusChange: ((Chat.Status?, String) -> Void)?

    var isConnected: Bool {
        return socket?.isConnected ?? false
    }

    required init(_ host: String, chatId: String, token: String?) {
        self.host = host
        self.chatId = chatId
        self.token = token

        super.init()

        self.setupSocket()
    }

    deinit {
        deinitSocket()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
    }
}

// MARK: Socket setup

extension WebSocketChatService {

    fileprivate func setupSocket() {
        guard let token = self.token else { return }
        guard let url = URL(string: "wss://\(host)/wschat/ws/?chatId=\(chatId)&token=\(token)") else { return }

        let credentialData = "\(1003):\(1003)".data(using: .utf8)!
        let base64Credentials = credentialData.base64EncodedString(options: [])

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")

        let socket = WebSocket(request: request, protocols: ["chat"])
        socket.delegate = self
        socket.pongDelegate = self

        self.socket = socket
    }

    fileprivate func deinitSocket() {
        socket?.disconnect(forceTimeout: 0)
        socket?.delegate = nil
        socket?.pongDelegate = nil
    }

    func refresh(_ token: String) {
        self.token = token
        deinitSocket()
        setupSocket()
    }
}

// MARK: Retryer

extension WebSocketChatService {

    fileprivate func reconnect() {
        if retryCount < maxRetryCount {
            retryCount += 1
            print("> WebSocket retry \(retryCount)")
            connect()
        } else {
            print("> WebSocket connect retry failed")
        }
    }
}

// MARK: WebSocketChatProtocol

extension WebSocketChatService: WebSocketChatServiceProtocol {

    func connect() {
        socket?.connect()
    }

    func disconnect() {
        socket?.disconnect()
    }

    func send(message: String) {
        socket?.write(string: message)
    }

    func send(message: WebSocketMessage) {
        if let messageString = message.stringParameters() {
            socket?.write(string: messageString)
        }
    }
}

// MARK: - WebSocketDelegate

extension WebSocketChatService: WebSocketDelegate {
    public func websocketDidConnect(socket: WebSocketClient) {
        onConnect?()
        retryCount = 0
    }

    public func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        onDisconnect?()
        startRetryTimer()
    }

    public func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print(text)
        guard let data = text.data(using: .utf8),
            let jsonData = try? JSONSerialization.jsonObject(with: data),
            let jsonDict = jsonData as? [String: Any],
            let message = WebSocketMessage(jsonDict: jsonDict) else {
                return
        }
        
//        guard let json = text.data(using: String.Encoding.utf8) else {
//            retryCount
//        }

        switch message.type {

        case .typing:
            if let (userId, isTyping) = message.typingData() {
                onTyping?(isTyping, userId)
            } else {
                onTyping?(true, nil)
            }
            startTypingTimer()

        case .message, .serviceMessage:
            do {
                let json = message.messageData()
                let jsonData = try json.rawData()
                let decoder = JSONDecoder()
                let responseObject = try? decoder.decode(HistoryChatMessage.self, from: jsonData)
                onMessage?(responseObject)
            } catch {
                print("Chat/messages parsing error")
            }
//            if let message = try? messageParser.parseData(message.messageData()) {
////                onMessage?(message)
//            }

        case .messageStatus:
            if let (messageId, status) = message.messageStatusData() {
                onMessageStatusChange?(messageId, status)
            }

        case .chatStatus:
            if let (status, text) = message.chatStatusData() {
                onChatStatusChange?(status, text)
            }
        }
    }

    public func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        
    }
}

// MARK: WebSocketPongDelegate

extension WebSocketChatService: WebSocketPongDelegate {

    func websocketDidReceivePong(socket: WebSocketClient, data: Data?) {
    }
}

// MARK: Timer

extension WebSocketChatService {

    fileprivate func startTypingTimer() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(WebSocketChatService.stopTypingTimer), object: nil)
        perform(#selector(WebSocketChatService.stopTypingTimer), with: nil, afterDelay: typingDelay)
    }

    @objc fileprivate func stopTypingTimer() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(WebSocketChatService.stopTypingTimer), object: nil)
        onTyping?(false, nil)
    }

    fileprivate func startRetryTimer() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(WebSocketChatService.stopRetryTimer), object: nil)
        perform(#selector(WebSocketChatService.stopRetryTimer), with: nil, afterDelay: retryDelay)
    }

    @objc fileprivate func stopRetryTimer() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(WebSocketChatService.stopRetryTimer), object: nil)
        reconnect()
    }
}

