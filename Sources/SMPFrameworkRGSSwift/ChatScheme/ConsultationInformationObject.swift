//
//  ConsultationInformationObject.swift
//  DRsdk
//
//  Source code
//

import Foundation

// MARK: - ConsultationInformationObject
struct ConsultationInformationObject: Codable {
    var specializationName: String?
    var specializationId: Int?
    var doctor: CIDoctorObject?
    var orderStatus: Int?
    var roomId: String?
    var status: String?
    var completeDate: String?
    //    "completeDate": "2020-11-20"
    //    const CODE_NEW = 'new';
    //    const CODE_ENDED = 'ended';
    // const CODE_CANCELED = 'canceled';
    // const CODE_WAITING = 'waiting';
    // const CODE_CONNECTED = 'connected';
    // const CODE_FILLED = 'filled';
    var emc: CIEmcObject?
    var chatId: Int?
//    var slot: TimeSlotDoctorObject?
    var isDuty: Bool?
    
    var documentPublicId: String?
    var documentAgreementSigned: Bool?
    var userIdsAccepted: Bool?
    var isPaid: Bool?
//    var clinic: ClinicObject?
    
    enum CodingKeys: String, CodingKey {
//        case clinic
        case specializationName
        case specializationId
        case doctor
        case orderStatus
        case status
        case roomId
        case emc
        case chatId
//        case slot
        case completeDate
        
        case isDuty
        case documentPublicId
        case isPaid
        case documentAgreementSigned
        case userIdsAccepted
    }
}

// MARK: - CIDoctorObject
public struct CIDoctorObject: Codable {
    public var photo: String?
    var id: Int?
    var isFavorite: Bool?
    var experience: Int?
    var middleName: String?
    var lastName: String?
    var firstName: String?
    public var fullName: String?
    
    enum CodingKeys: String, CodingKey {
        case photo
        case id
        case isFavorite
        case experience
        case middleName
        case lastName
        case firstName
        case fullName
    }
}

// MARK: - Emc
struct CIEmcObject: Codable {
    var name: String?
    var lastName: String?
    var middleName: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case lastName
        case middleName
    }
}

