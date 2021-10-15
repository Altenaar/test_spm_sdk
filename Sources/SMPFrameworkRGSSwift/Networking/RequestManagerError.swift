//
//  RequestManagerError.swift
//  DRsdk
//
//  Source code
//

import Foundation
import SwiftyJSON

struct RequestManagerError: NetworkError {
    var code: Int
    var message: String?
}

protocol RequestManagerErrorParserProtocol {
    func parseErrorJSON(_ json: JSON) -> RequestManagerError
}

class RequestManagerErrorParser: RequestManagerErrorParserProtocol {
    func parseErrorJSON(_ json: JSON) -> RequestManagerError {
        guard let code = json["code"].int else {
            return RequestManagerError(code: 9999, message: "unknown_error")
        }
        return RequestManagerError(code: code, message: json["message"].string)
    }
}

