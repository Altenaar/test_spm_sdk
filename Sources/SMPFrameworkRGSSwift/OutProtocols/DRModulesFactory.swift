//
//  DRModulesFactory.swift
//  DRsdk
//
//  Created by Артем Чурсин on 09.04.2021.
//

import Foundation

///Инициализация модулей SDK
public protocol DRModulesFactory {
    ///Генерация модуля работы с чатом
    func getChatModule() -> ChatModule
    ///Генерация модуля работы с аудио и видео
    func getCallsModule() -> CallsModule
}

public class DRModulesFactoryImp: DRModulesFactory {
    public init() {}
    
    ///Генерация модуля работы с чатом
    public func getChatModule() -> ChatModule {
        let chatModule: ChatModule = ChatModuleImp()
        return chatModule
    }
    
    ///Генерация модуля работы с аудио и видео
    public func getCallsModule() -> CallsModule {
        let callsModule: CallsModule = CallsModuleImp()
        return callsModule
    }
}
