//
//  CallsModule.swift
//  DRsdk
//
//  Created by Артем Чурсин on 09.04.2021.
//

import Foundation
import RxSwift
import UIKit

public protocol VideoViewWebRtc {
    var localView: UIView { get set }
    var remoteView: UIView { get set }
}

public protocol CallsModule {

    /**
    Инициализация чата.
       * Перед работой чата необходимо вызвать этот метод.
     - Parameter consultationId: id консультации
     - Parameter token: токен
     - Parameter userToken: токен пользователя
    */
    func create(consultationId: String,
                token: String,
                userToken: String)
    
    /**
     Subject, в который прокидываются события при входящем звонке
     */
    var incomingCallSubject: PublishSubject<IncomingCallInfo> {get}

    /**
     Вызывается для принятия входящего звонка. Срабатывает только если есть активный входящий звонок. В противном случае ничего не происходит
     - Parameter localSurfaceView:  View, где будет отображаться локальное видео (видео с камеры)
     - Parameter remoteSurfaceView : View, где будет отображаться удаленное видео (видео оппонента)
     */
    func acceptCall()

    /**
     * Вызывается для отклонения входящего звонка. Срабатывает только если есть активный входящий
     * звонок. В противном случае ничего не происходит
     */
    func rejectCall()
    
    /**
     * Использовать для отключения от видео вызова, на кнопке завершения вызова.
     */
    func completeCall()

    /**
     * Включение/выключение микрофона
     */
    var muted: Bool {get set}

    /**
     * Включение/выключение громкой связи
     */
    var speakerEnabled: Bool {get set}

    /**
     * Включение/выключение камеры
     */
    var cameraEnabled: Bool {get set}

    /**
     * Переключение кмеры
     */
    func switchCamera()
    
    /**
     * for video call
     * stateTelemedConnect 1  - connect 0 - disconnect
     */
//    var remoteVideo: PublishSubject<RTCVideoTrack?> {get}
//    var localVideo: PublishSubject<RTCVideoTrack?> {get}
    var updateSizeVideoView: PublishSubject<CGSize?> {get} // return update size for video
    func clearCall() // use if call end
    func changeRotationCamera() // change rotation local camera
    func setVideoCallScreen(callView: VideoViewWebRtc) // set callScreen for set video remote and local
    var stateTelemedConnect: PublishSubject<Int> {get}
}
