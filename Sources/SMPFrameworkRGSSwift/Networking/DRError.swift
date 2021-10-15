//
//  DRError.swift
//  DRsdk
//
//  Created by Artem Ermochenko on 8/17/21.
//

import Foundation

class DRError : Error & Codable {
    var code : Int
    var name : String    
}

class ErrorData : Codable {
    var error : DRError
}
