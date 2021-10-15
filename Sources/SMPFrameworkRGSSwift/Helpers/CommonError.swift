//
//  CommonError.swift
//  DRsdk
//
//  Source code
//

import Foundation

enum CommonError: Error {
    case dataNotSupported
    case wrongJSON
    case classWrongConfigured
    case makingRequestWhenNotAuth
    case encodingError
    case customError(String)
}

extension CommonError: LocalizedError {
    func descriptionMessageForError() -> String {
        return errorDescription ?? ""
    }

    public var errorDescription: String? {
        switch self {
        case .wrongJSON:
            return "error_occurred_while_processing_received_data"
        case .dataNotSupported:
            return "unsupported_data_format"
        case .classWrongConfigured:
            return "error_object_not_properly_configured"
        case .makingRequestWhenNotAuth:
            return "an_unregistered_user_tries_to_make_a_request"
        case .encodingError:
            return "error_encoding_data"
        case .customError(let errorText):
            return errorText
        }
    }
}
