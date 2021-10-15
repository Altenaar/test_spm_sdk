//
//  Storage.swift
//  DRsdk
//
//  Source code
//

import Foundation

struct Storage {
    
}

// MARK: - Authorization
extension Storage {
    static var tokenAppAuth: String? {
        get {
            let lastModifiedInt = UserDefaults.standard.string(forKey: "tokenAppAuth")
            return lastModifiedInt
        }
        set (newVal) {
            UserDefaults.standard.set(newVal, forKey: "tokenAppAuth")
            UserDefaults.standard.synchronize()
        }
    }
}
