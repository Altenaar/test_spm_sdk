//
//  LoginStorage.swift
//  DRsdk
//
//  Source code
//

import Foundation
import SwiftyJSON

private let encoder = JSONEncoder()

protocol LoginStorageProtocol: class {
    var token: String? { get set }
    var refreshToken: String? { get set }
}

class LoginStorage: LoginStorageProtocol {
    let userDefaults: UserDefaults

    fileprivate let refreshTokenUserDefaultsKey = "DOCRefreshTokenUserDefaultsKey"
    

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
    }


    var token: String? {
        get {
            
            return userDefaults.string(forKey: refreshTokenUserDefaultsKey)
        }
        set {
            if let newValueUnwraped = newValue {
                userDefaults.set(newValueUnwraped, forKey: refreshTokenUserDefaultsKey)
                userDefaults.synchronize()
            } else {
                userDefaults.removeObject(forKey: refreshTokenUserDefaultsKey)
                userDefaults.synchronize()
            }
        }
    }

    var refreshToken: String? {
        get {

            return userDefaults.string(forKey: refreshTokenUserDefaultsKey)
        }
        set {
            if let unwrapText = newValue, unwrapText.count > 10 {
                userDefaults.set(newValue, forKey: refreshTokenUserDefaultsKey)
                userDefaults.synchronize()
            }
        }
    }
}
