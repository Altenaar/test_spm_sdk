//
//  LoginManager.swift
//  DRsdk
//
//  Source code
//

import Foundation
import SwiftyJSON
import Alamofire

typealias LoginManagerProtocolCompletedBlock = ((_ error: Error?) -> Void)

protocol LoginManagerProtocol: class {
    var loginStorage: LoginStorageProtocol {get}
    func refreshUserToken(_ didCompleteClosure: @escaping LoginManagerProtocolCompletedBlock)

    func deleteToken()
}

class LoginManager: LoginManagerProtocol {
    
    let loginStorage: LoginStorageProtocol
    private let requestManager: RequestManagerProtocol
    
    
    init(loginStorage: LoginStorageProtocol,
         requestManager: RequestManagerProtocol) {
        
        self.loginStorage = loginStorage
        self.requestManager = requestManager
    }
    
    func refreshUserToken(_ didCompleteClosure: @escaping LoginManagerProtocolCompletedBlock) {
        guard let unwrapRefreshToken = self.loginStorage.refreshToken, unwrapRefreshToken != "" else {
            let error = CommonError.makingRequestWhenNotAuth
            print(error)
            didCompleteClosure(error)
            return
        }
        
        var parameters = [
            "refreshToken": "\(unwrapRefreshToken)"
            ] as [String: Any]
        
        _ = requestManager.makePostRequest("user/refresh", parameters: parameters as [String : AnyObject], completedBlock: { result in
            switch result {
            case .success(let json):
//                self.loginStorage.saveUserWithJSON(json)
                didCompleteClosure(nil)
            case .failure(let error):
                didCompleteClosure(error)
            }
        })
    }
    
    func deleteToken() {
        loginStorage.token = nil
        loginStorage.refreshToken = nil
    }
}

