//
//  Consultation.swift
//  DRsdk
//
//  Created by Артем Чурсин on 16.04.2021.
//

import Foundation

struct JoinConsultation {
    var clientId: String?
    var wssUrl: String?
    var wssPostUrl: String?
    var isInitiator: String?
    var roomId: String?
    var useMediaServer: Bool?

    // turn servers
    var turnServers: [String]?
    var usernameTurn: String?
    var credentialTurn: String?
}

public enum CommunicationType: String {
    case video
    case audio
    case chat
}

struct Consultation {

    /// Get all available statuses at "/api/reference"
    enum Status: String {
        /// Ожидает соединения
        case waiting = "Q"
        /// Соединена
        case opened = "R"
        /// Завершена
        case closed = "S"
        /// СМП, Скорая медицинская помощь (EMS, Emergency medical services)
        case ems = "T"
        /// Заполнена
        case filled = "U"
        /// Отменена
        case cancelled = "V"
        /// Подписка
        case subscription = "W"
        /// Ожидает оплаты
        case waitingForPayment = "X"
    }
    var specialisationName: String?

    var bonusMoneyId: Int?
//    var bonusMoney: [OrderBonusMoney]?

    var questionsEnabled: Bool?
    var name: String?
    var consultDoctorsList = [ConsultDoctorsListModel]()
    var instrumentalInvestigations = [String]()
    var assaysList = [Int: String]()
    var recommendationList = [String]()
    var diseaseList = [String]()
    var drugList = [String]()
    var medicalAcceptUrl: String?
    var agreementUrl: String?
    var warningMessage: String?

    var id: Int?
    var step: Int?
    var dateInsert: String?
    var dateReservation: String?
    var doctorId: String?
    var statusId: Status?
    var userId: String?
    var roomId: String?
    var channel: String?
    var chatId: Int?
    var communicationTypeTelemed: String?

    var communicationType: CommunicationType = .chat
//    var type: ConsultationDoctorViewController.ConsultationType?

    var statusName: String?

//    var authorizationPublicServices: [AuthorizationPublicServiceModel] = []

    var price: ModelConsultationPrice?
    var conclusion: ModelConsultationConclusion?
    var basket: [ModelConsultationBasket]?

    // bank card
    var cardNumber: String?
    var cardType: String?

    // patient
    var patient: ModelPatientConsultation?
//    var doctor: ModelDoctorConsultation?
//    var availablePatients: [OrderPatient] = [] // for consultation order
//    var availableRepresentatives: [OrderPatient] = [] // for consultation order

    // main
    var doctorTypeId: String?
    var patientId: String?
    var payCardId: Int?
    var coupon: String?

    var paySystemId: Int?
    var partnerOrder: Bool? // insurance
    var trafficSourceId: Int? // referral source
    var specializationTitle: String?
    
    //selected time
    var intervalId: String?
//    var timeDayFromWeek: [TimeDayFromWeek]?
//    var doctorsForSelect: [ModelDoctor]?

    var authorizationPublicServiceId: Int64?
    var representativeId: Int64?
    
    
    var isPromoFieldAvailable = false

    func JSONParams() -> [String: AnyObject] {
        var params = [String: AnyObject]()

        if let step = self.step {
            params["step"] = step as AnyObject
        }
        params["consultation"] = JSONParamsMain() as AnyObject

        return params
    }

    /// Consultation that not finished yet. That is, not in any of statuses like cancelled, closed, filled, etc.
    var isActive: Bool {
        return statusId == .waiting || statusId == .opened
    }

    func JSONParamsMain() -> [String: AnyObject] {
        var params = [String: AnyObject]()

        if let bonusMoneyId = self.bonusMoneyId {
            params["bonusMoneyId"] = bonusMoneyId as AnyObject
        }
        if let payCardId = self.payCardId {
            params["payCardId"] = payCardId as AnyObject
        }
        if let trafficSourceId = self.trafficSourceId {
            params["trafficSourceId"] = trafficSourceId as AnyObject
        }
        if let partnerOrder = self.partnerOrder {
            params["partnerOrder"] = partnerOrder as AnyObject
        }
        if let paySystemId = self.paySystemId {
            params["paySystemId"] = paySystemId as AnyObject
        }
        if let intervalId = self.intervalId {
            params["intervalId"] = intervalId as AnyObject
        }
//        if let doctorId = self.doctor?.doctorId {
//            params["doctorId"] = doctorId as AnyObject
//        }
        if let doctorTypeId = self.doctorTypeId {
            params["doctorTypeId"] = doctorTypeId as AnyObject
        }
        if let patientId = self.patientId {
            params["patientId"] = patientId as AnyObject
        }
        if let payCardId = self.payCardId {
            params["payCardId"] = payCardId as AnyObject
        }
        if let coupon = self.coupon {
            params["coupon"] = coupon as AnyObject
        }
        if let authType = self.authorizationPublicServiceId {
            params["authTypeId"] = authType as AnyObject
        }
        if let representativeId = self.representativeId {
            params["representativeId"] = representativeId as AnyObject
        }
//        if let communicationType = self.type, communicationType == .question {
//            params["communicationType"] = "question" as AnyObject
//        }

        return params
    }

    // peivate
//    func returnDate() -> String {
//        if let unwrapDate = dateInsert {
//            let dateCurrent = DateFormatter.doc_dateTimeFormatOrder().date(from: unwrapDate)
//            if let unwrapStringDate = dateCurrent {
//                return DateFormatter.doc_formatMonthDayTime().string(from: unwrapStringDate)
//            }
//        }
//        return ""
//    }
}

struct ConsultDoctorsListModel {
    var nameSpecialization: String?
    var specializationId: Int?
}

//struct ModelPatientConsultation

struct ModelPatientConsultation {
    var id: Int? //имя
    var name: String? //имя
    var middleName: String? //отчество
    var surname: String? //фамилия
    var urlImage: String?
    var fio: String?
    var medicalAccept: Bool? // разрешение госуслуг
}

//struct ModelDoctorConsultation

//struct ModelDoctorConsultation: PersonDoctor {
//    var doctorId: Int? //
//    var specialisationName: String?
//    var name: String? //имя
//    var middleName: String? //отчество
//    var surname: String? //фамилия
//    var avatar: String?
//    var description: String?
//    var type: String?
//}

//struct ModelСonsultationBasket

struct ModelConsultationBasket {
    var id: String? //
    var name: String? //
    var price: String? //
    var doctorType: String? //
    var quantity: String? //
    var icon: String?
}

//struct ModelConsultationConclusion

struct ModelConsultationConclusion {
    var drugs: [String]?
    var consultations: [String]?
    var analysis: [String]?
    var care: [String]?
}

//struct ModelConsultationPrice

struct ModelConsultationPrice {
    var total: Int?
    var discount: Int?
    var sumPaid: Int?
    var psSum: Int?
    var toPay: Int?
    var name: String?

    func JSONParams() -> [String: AnyObject] {
        var params = [String: AnyObject]()

        if let total = self.total {
            params["total"] = total as AnyObject
        }
        if let discount = self.discount {
            params["discount"] = discount as AnyObject
        }
        if let sumPaid = self.sumPaid {
            params["sumPaid"] = sumPaid as AnyObject
        }
        if let psSum = self.psSum {
            params["psSum"] = psSum as AnyObject
        }
        if let toPay = self.toPay {
            params["toPay"] = toPay as AnyObject
        }
        return params
    }
}

