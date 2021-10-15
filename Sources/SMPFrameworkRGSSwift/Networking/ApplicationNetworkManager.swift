//
//  ApplicationNetworkManager.swift
//  DRsdk
//
//  Source code
//

import Foundation

protocol ApplicationNetworkManagerProtocol {
    var applicationToken: String? { get }
    func refreshApplicationToken(_ didCompleteClosure:@escaping ((Bool) -> Void))
}

class ApplicationNetworkManager: ApplicationNetworkManagerProtocol {
    var userDefaults: UserDefaults?
    var requestManager: RequestManagerProtocol?
    var applicationNetworkManagerParameters: ApplicationNetworkManagerParametersProtocol?

    var applicationToken: String? {
        return Storage.tokenAppAuth
    }

    func refreshApplicationToken(_ didCompleteClosure: @escaping ((Bool) -> Void)) {

        guard let
        requestManager = self.requestManager,
        let parameters = self.applicationNetworkManagerParameters else {
            didCompleteClosure(false)
            return
        }
        _ = requestManager.makePostRequest("app/auth", parameters: [
                "login": parameters.login as AnyObject,
                "password": parameters.password as AnyObject
        ], completedBlock: { result in
            switch result {
            case .success(let json):
                print("json \(json)")
                if let applicationToken = json["data"]["accessToken"].string {
                    Storage.tokenAppAuth = applicationToken
                    didCompleteClosure(true)
                } else {
                    didCompleteClosure(false)
                }
            case .failure:
                didCompleteClosure(false)
            }
        })
    }
}

protocol ApplicationNetworkManagerParametersProtocol {
    var login: String { get }
    var password: String { get }
}

//class ApplicationNetworkManagerDemoParameters: ApplicationNetworkManagerParametersProtocol {
//    var login: String {
//        if StaticConstants.isB2b {
////            return "anonymous-ios"
//            return "anonymous"
//        }
//        if StaticConstants.isFranchize {
//            return "fransh"
//        }
//        return "android"
//    }
//    var password: String {
//        if StaticConstants.isB2b {
////            return "9d65XRm3LC2jrFS3"
//            return "2EcMvkYCNC2Eks8X"
//        }
//        if StaticConstants.isFranchize {
//            return "o1uU13~cOpwC"
//        }
//        return "o1uU13~cOpwC"
//    }
//}

