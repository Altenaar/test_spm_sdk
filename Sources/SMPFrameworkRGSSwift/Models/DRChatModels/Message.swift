//
//  Message.swift
//  DRsdk
//
//  Created by Артем Чурсин on 01.04.2021.
//

import UIKit

class Message {

    enum Status: String {
        /// Новое сообщение
        case new = "new"
        /// Отправлено PUSH уведомление
        case push = "push"
        /// Сообщение получено устройстом
        case received = "recd"
        /// Сообщение прочитано получателем
        case read = "read"
        /// Сообщение создано клиентом, но не отправлено
        case created = "crtd"
        /// Сообщение создано клиентом, но не отправлено из-за отсутствия соединения
        case error = "error"

        var image: UIImage? {
            switch self {
            case .new, .created:
                return UIImage(named: "message-status-created")
            case .received:
                return UIImage(named: "message-status-received")
            case .read:
                return UIImage(named: "message-status-read")
            case .error:
                return UIImage(named: "message-status-failed")
            default:
                return nil
            }
        }
    }
    
    //doctor
    var docName: String?
    var docImage: String?
    var docSpecialization: String?

    var image: UIImage?
    var thumbnailImage: UIImage?

    /// Unique message ID created on sender side. For client messages `messageId` != `messageRealId`.
    var messageId: String = NSUUID().uuidString.lowercased()

    /// Unique message ID created on server side.
    var messageRealId: String?
    var chatId: Int = 0
    var id: Int = 0
    var userId: Int64 = 0
    var dateInsert: Date = Date()
    var name = ""
    var message: String = ""
    var urlAvatar: String?
    var urlFile: String?
    var thumbnail: String?
    var serviceMessage: String?
    private var _dataType: Int = MessageDataType.message.rawValue
    var dataType: MessageDataType {
        get {
            return MessageDataType(rawValue: _dataType) ?? .message
        }
        set {
            _dataType = newValue.rawValue
        }
    }

    private var _userType: String = UserType.client.rawValue
    var userType: UserType {
        get {
            return UserType(rawValue: _userType) ?? .client
        }
        set {
            _userType = newValue.rawValue
        }
    }

    private var _status: String = Status.created.rawValue
    var status: Status {
        get {
            return Status(rawValue: _status) ?? .created
        }
        set {
            _status = newValue.rawValue
        }
    }

    private var _clientStatus: String = Status.created.rawValue
    /// Статус прочитанности входящего сообщения клиентом.
    var clientStatus: Status {
        get {
            return Status(rawValue: _clientStatus) ?? .read
        }
        set {
            _clientStatus = newValue.rawValue
        }
    }

    var answerType: String?
    var smartQuestionId: Int = 0

    var questionId: String?
//    let answers = List<RealmString>()
    var answer: AnswerType {
        get {
            return AnswerType(rawValue: answerType ?? "none") ?? .none
        }
        set {
            answerType = newValue.rawValue
        }
    }
    var button: MessageButtonRealm?

    convenience init(dateInsert: Date, chatId: Int, userId: Int64, message: String, name: String, userType: UserType, url: String?, image: UIImage?, dataType: MessageDataType) {
        self.init()
        self.urlFile = url
        self.dataType = dataType
        self.image = image
        self.dateInsert = dateInsert
        self.userId = userId
        self.chatId = chatId
        self.message = message
        self.name = name
        self.userType = userType
    }

    convenience init(_ message: String, name: String, chatId: Int, userId: Int64) {
        self.init()
        self.message = message
        self.name = name
        self.chatId = chatId
        self.userId = userId
    }
}

// MARK: - ChatMessageType
//extension Message: ChatMessageType {
//    var sender: SenderType {
//        return Sender(id: "\(userId)", displayName: name)
//    }
//
//    var sentDate: Date {
//        return dateInsert
//    }
//
//    var savedFileName: String {
//        return self.message
//    }
//
//    var kind: MessageKind {
//        switch dataType {
//        case .image:
//            let url: URL? = {
//                guard let url = urlFile else { return nil }
//                return URL(string: url)
//            }()
//            return .photo(ChatMediaItem(url: url, image: image, placeholderImage: thumbnailImage ?? #imageLiteral(resourceName: "ava_alpha")))
//        case .doc, .excel, .pdf, .unknown, .dicom, .pages, .numbers:
//            let attributes = DOCStyle.chatMessageAttributes(textColor: textColor)
//            let attributedText = NSAttributedString(string: message, attributes: attributes)
//            return .custom(MessageCustomKind.document(text: attributedText))
//        case .button:
//            let attributes = DOCStyle.subheaderAttributes(color: textColor)
//            // NOTE: Размер кнопки фиксированный, но сервер возвращает текст,
//            // не умещающийся в одну строку. Оставляем обрезку текста без "..."
//            //let text = message.truncatedTo(width: 222 - 32, attributes: attributes, tail: "...")
//            let text = message
//            let attributedText = NSAttributedString(string: text, attributes: attributes)
//            let backgroundColor: UIColor = {
//                guard let button = button, !button.backgroundColor.isEmpty else { return .coal(2) }
//                return DOCStyle.DocColor.hexString(button.backgroundColor).color
//            }()
//            return .custom(MessageCustomKind.button(title: attributedText,
//                                                    backgroundColor: backgroundColor,
//                                                    deeplink: button?.link))
//        case .doctor:
//            // NOTE: we can't get doctor info here, server doesn't provide it on this level
//            return .custom(MessageCustomKind.doctorInfo(name: docName,
//                                                        specialization: docSpecialization,
//                                                        avatarURL: docImage))
//        default:
//            let attributes = DOCStyle.chatMessageAttributes(textColor: textColor)
//            return .attributedText(NSAttributedString(string: message, attributes: attributes))
//        }
//    }
//
//    var thumbnailURL: String? {
//        return thumbnail
//    }
//
//    var isMediaLoaded: Bool {
//        switch dataType {
//        case .image:
//            return image != nil
//        default:
//            return false
//        }
//    }
//
//    var textColor: DOCStyle.DocColor {
//        switch dataType {
//        case .doc, .excel, .pdf, .unknown, .dicom, .pages, .numbers:
//            return DOCStyle.DocColor.coal(6)
//        case .button:
//            let docColor: DOCStyle.DocColor = {
//                guard let button = button, !button.textColor.isEmpty else { return .coal(6) }
//                return DOCStyle.DocColor.hexString(button.textColor)
//            }()
//            return docColor
//        default:
//            return (userType == .client) ? .white : .coal(6)
//        }
//    }
//
//    func update(_ image: UIImage) {
//        self.image = image
//    }
//}
//
//extension Message {
//    func isSameSender(message: ChatMessageType) -> Bool {
//        return sender.senderId == message.sender.senderId && userType == message.userType
//    }
//
//    func updateThumbnailImage(_ image: UIImage) {
//        self.thumbnailImage = image
//    }
//
//    /// Web socket parameters.
//    func JSONParams() -> [String: Any] {
//        var params = [String: Any]()
//
//        params["messageId"] = messageId
//        params["message"] = message
//        params["userId"] = userId
//        params["chatId"] = chatId
//        if let questionId = questionId {
//            params["questionId"] = questionId
//        }
//
//        return params
//    }
//}
//
extension Message {
    enum AnswerType: String {
        case text
        case choice
        case file
        case none
    }

    enum UserType: String {
        case createOrder = "order_created"
        case serviceSystemInfo = "system_info"
        case client = "client"
        case `operator` = "operator"
        case doctor = "doctor"
        case personalDoctor = "personalDoctor"
        case telemedDoctor = "telemedDoctor"
        case doctorOnDuty = "doctor_on_duty"
        case bot = "bot"
        case service = "service"

        var isSystem: Bool {
            switch self {
            case .client, .operator, .doctor, .telemedDoctor, .bot:
                return false
            default:
                return true
            }
        }
    }
}

class MessageButtonRealm {
    var link = ""
    var textColor = ""
    var backgroundColor = ""
}

enum MessageCustomKind {
    case document(text: NSAttributedString)
    case doctorInfo(name: String?, specialization: String?, avatarURL: String?)
    case button(title: NSAttributedString, backgroundColor: UIColor, deeplink: String?)
}

//private struct ChatMediaItem: MediaItem {
//    var url: URL?
//    var image: UIImage?
//    var placeholderImage: UIImage
//
//    var size: CGSize {
//        let image = self.image ?? placeholderImage
//        switch image.orientation {
//        case .portrait: return CGSize(width: 160, height: 240)
//        default: return CGSize(width: 240, height: 160)
//        }
//    }
//
//    init(url: URL?, image: UIImage? = nil, placeholderImage: UIImage = #imageLiteral(resourceName: "ava_alpha")) {
//        self.url = url
//        self.image = image
//        self.placeholderImage = placeholderImage
//    }
//}

