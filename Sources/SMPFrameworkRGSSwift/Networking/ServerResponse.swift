//
//  ServerResponse.swift
//  DRsdk
//
//  Source code
//

import Foundation

struct ServerResponse<T: Decodable> {
    let success: Bool
    let data: T?
    let error: ServerError?

    enum CodingKeys: String, CodingKey {
        case success
        case data
    }

    enum ErrorCodingKeys: String, CodingKey {
        case error = "errors"
    }
}

extension ServerResponse: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)

        if let data = ((try? container.decodeIfPresent(T.self, forKey: .data)) as T??) {
            self.data = data
            error = nil
        } else {
            data = nil

            let errorContainer = try container.nestedContainer(keyedBy: ErrorCodingKeys.self, forKey: .data)
            if let error = ((try? errorContainer.decodeIfPresent(ServerError.self, forKey: .error)) as ServerError??) {
                self.error = error
            } else {
                error = ServerError.unknownError
            }
        }
    }
}

protocol NetworkError: Error {
    var code: Int { get }
    var message: String? { get }
}

struct ServerError: NetworkError, Decodable {
    let code: Int
    let message: String?

    static var unknownError: ServerError {
        return ServerError(code: 9999, message: "unknown_error")
    }
}

