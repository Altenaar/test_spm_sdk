//
//  IncomingCallInfo.swift
//  DRsdk
//
//  Created by Артем Чурсин on 09.04.2021.
//

/**
 * Информация о входящем звонке
 * - version:
 * 1.0.0
 */
public class IncomingCallInfo {
    
    var photo: String?
    var specialization: String?
    var name: String?
    
    /// Создание информации о входящем звонке
    ///
    /// - parameter name:   ФИО звонящего
    /// - parameter photo:  Фотография звонящего
    /// - parameter specialization:   Специализация звонящего
    init(name: String?,
         photo: String?,
         specialization: String?) {
        self.name = name
        self.photo = photo
        self.specialization = specialization
    }
}
