//
//  ChatModule.swift
//  DRsdk
//
//  Created by Артем Чурсин on 24.03.2021.
//

import Foundation
import RxSwift

public protocol ChatModule {
    /**
    Инициализация чата.
       * Перед работой чата необходимо вызвать этот метод.
     - Parameter consultationId: id консультации
     - Parameter token: токен
     - Parameter userToken: токен пользователя
    */
    func create(consultationId: String, token: String, userToken: String) -> Completable
    
    /**
     Завершается работу чата.
     * Происходит остановка подписки на обновление чата.
     * Если были сообщения в статусе SEND_FAILED, то они пропадут из истории.
     * После вызова этого метода не гарантируется доставка сообщений в статусе SENDING.
     */
    func destroy()
    
    /**
     В этом параметре хранится история чата
    */
    var chatHistory: [HistoryChatMessage] { get }
    
    /**
    Отправка сообщения в чат.
     * Вызов данного метода не гарантирует доставку сообщения.
     * Отслеживание статуса сообщение необходимо проводить в истории чата

     - Parameter message: отправляемое сообщениее
     */
    func sendMessage(message: OutgoingChatMessage)
    
    /**
     Subject, в который прокидываются события, когда изменяется статус набора текста оппонента
    */
    var onOpponentWritingStatusChangeSubject: PublishSubject<OpponentWritingStatus> { get }
    
    /**
     Получение последнего известного статуса набора текста оппонента
     */
    func getLastKnownOpponentWritingStatus() -> OpponentWritingStatus
    
    /**
     Subject, в который прокидываются события, когда изменяется онлайн-статус оппонента
    */
    var onOpponentOnlineStatusChangeSubject: PublishSubject<OpponentOnlineStatus> { get }
    
    /**
     Текущий онлайн-статус оппонента
     */
    func getOpponentOnlineStatus() -> OpponentOnlineStatus
    
    /**
     Загружает историю сообщений чата
     - Parameter lastMessageId: ID последнего сообщения, видимого в чате. Если его не передавать, то будут возвращены последние сообщения
     - Parameter maxMessages: максимальное количество сообщений, которое тянется
     - Returns: Сообщения истории. Если возвращается пустой список, значит сообщений в истории больше нет
     */
    func loadChatHistory(lastMessageId: String?, maxMessages: Int) -> Observable<[HistoryChatMessage]>
    
    /**
     Информирует о том, что пользователь набирает сообщение
     - Parameter typing: Информирует о том, что пользователь набирает сообщение
     */
    func isUserTyping(_ isTyping: Bool)
    
    /**
     Closure, в который прокидывается новое сообщение
     */
    var onMessage: ((HistoryChatMessage?) -> Void)? { get set }
}
