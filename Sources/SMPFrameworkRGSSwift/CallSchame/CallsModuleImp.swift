//
//  CallsModuleImp.swift
//  DRsdk
//
//  Created by Артем Чурсин on 16.04.2021.
//

import Foundation
import RxSwift
import WebRTC

enum VideoViewControllerCameraPosition {
    case front
    case back
}

class CallsModuleImp: CallsModule {
    private var requestManager: RequestManagerProtocol = RequestManager(host: "https://test-api.drtelemed.ru/api/v1/", token: "", userToken: "")
    var telemedConnectionService: TelemedConnectionServiceProtocol?
    
    //video
    var videoCallScreen: VideoViewWebRtc?
    var bag = DisposeBag()
    
    private var localVideoTrack: RTCVideoTrack?
    private var remoteVideoTrack: RTCVideoTrack?
    private var localView = RTCCameraPreviewView()
    private var remoteView = RTCEAGLVideoView()
    private var localCapturer: RTCCameraVideoCapturer?
    
    var position: VideoViewControllerCameraPosition = .front
    var incomingCallSubject = PublishSubject<IncomingCallInfo>()
    var muted: Bool = false
    var speakerEnabled: Bool = true {
        didSet {
            speakerEnabled ? telemedConnectionService?.unmuteAudioIn() : telemedConnectionService?.muteAudioIn()
        }
    }
    var cameraEnabled: Bool = false {
        didSet {
            if cameraEnabled {
                telemedConnectionService?.unmuteVideoIn()
            } else {
                telemedConnectionService?.muteVideoIn()
            }
        }
    }
    
    // video connection
    var errorInVideoConnect = PublishSubject<Error?>() // not need
    var updateSizeVideoView = PublishSubject<CGSize?>() // not need
    var stateTelemedConnect = PublishSubject<Int>() //stateTelemedConnect 1  - connect 0 - disconnect
    
    func create(consultationId: String,
                token: String,
                userToken: String) {
        requestManager = RequestManager(host: "https://test-api.drtelemed.ru/api/v1/", token: token , userToken: userToken)
        telemedConnectionService = TelemedConnectionService(telemedService: TelemedService(requestManager: requestManager),
                                                            consultationID: Int(consultationId),
                                                            token: userToken)
        errorInVideoConnect.onNext(nil)
        updateSizeVideoView.onNext(nil)
        stateTelemedConnect.onNext(0)
        telemedConnectionService?.delegate = self
        
        telemedConnectionService?.localVideoTrack.asObservable().subscribe(onNext: { [weak self] videoTrack in
            guard let strongSelf = self, let videoTrack = videoTrack else { return }
            strongSelf.updateLocalVideoTrack(videoTrack)
        })
        .disposed(by: bag)
        telemedConnectionService?.remoteVideoTrack
            .asObservable().subscribe(onNext: { [weak self] videoTrack in
                guard let strongSelf = self, let videoTrack = videoTrack else { return }
                strongSelf.updateRemoteVideoTrack(videoTrack)
            })
            .disposed(by: bag)
        telemedConnectionService?.localVideoCapturer.asObservable().subscribe(onNext: { [weak self] capturer in
            guard let strongSelf = self, let capturer = capturer else { return }
            strongSelf.updateLocalViewCaptureTrack(capturer)
            
        }).disposed(by: bag)
    }
    
    func switchCamera() {
        changeRotationCamera()
    }
    
    func acceptCall() {
        telemedConnectionService?.callUp()
    }
    
    func rejectCall() {
        telemedConnectionService?.sendBye()
    }
    
    func completeCall() {
        telemedConnectionService?.completeTelemedCall()
//        clearCall()
    }
    
    func setVideoCallScreen(callView: VideoViewWebRtc) {
        videoCallScreen = callView
        videoCallScreen?.remoteView.addSubview(remoteView)
        videoCallScreen?.localView.addSubview(localView)
        videoCallScreen?.remoteView.translatesAutoresizingMaskIntoConstraints = false
        videoCallScreen?.localView.translatesAutoresizingMaskIntoConstraints = false
        
        localView.translatesAutoresizingMaskIntoConstraints = false
        if let superview = videoCallScreen?.localView {
            NSLayoutConstraint.activate([
                localView.topAnchor.constraint(equalTo: superview.topAnchor),
                localView.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
                localView.leftAnchor.constraint(equalTo: superview.leftAnchor),
                localView.rightAnchor.constraint(equalTo: superview.rightAnchor)
            ])
        }
        
        remoteView.translatesAutoresizingMaskIntoConstraints = false
        if let superview = videoCallScreen?.remoteView {
            NSLayoutConstraint.activate([
                remoteView.topAnchor.constraint(equalTo: superview.topAnchor),
                remoteView.bottomAnchor.constraint(equalTo: superview.bottomAnchor),
                remoteView.leftAnchor.constraint(equalTo: superview.leftAnchor),
                remoteView.rightAnchor.constraint(equalTo: superview.rightAnchor)
            ])
        }
        remoteView.delegate = self
    }
    
    func clearCall() {
        localView.removeFromSuperview()
        remoteView.removeFromSuperview()
        localView = RTCCameraPreviewView()
        remoteView = RTCEAGLVideoView()
        localCapturer = nil
        remoteVideoTrack = nil
    }
}

//MARK: - RTCEAGLVideoViewDelegate
extension CallsModuleImp: RTCVideoViewDelegate {
    func videoView(_ videoView: RTCVideoRenderer, didChangeVideoSize size: CGSize) {
        if remoteVideoTrack != nil {
            updateSizeVideoView.onNext(size)
        }
    }
}

extension CallsModuleImp {
    
    func changeRotationCamera() {
        if let localCapturer = localCapturer {
            localCapturer.stopCapture()
            let camPosition: AVCaptureDevice.Position = (position == .front) ? .back : .front
            position = (position == .front) ? .back : .front
            let device = self.findDevice(camPosition)
            let format: AVCaptureDevice.Format? = selectFormat(for: device)
            
            if format == nil {
                print("No valid formats for device %@", device)
                assert(false, "")
                
                return
            }
            
            let fps = selectFps(for: format)
            
            localCapturer.startCapture(with: device, format: format!, fps: fps)
            self.localCapturer = localCapturer
        }
    }
    
    func selectFormat(for device: AVCaptureDevice?) -> AVCaptureDevice.Format? {
        let formats = RTCCameraVideoCapturer.supportedFormats(for: device!)
        let targetWidth = 1280
        let targetHeight = 720
        var selectedFormat: AVCaptureDevice.Format?
        var currentDiff = Int(Int32.max)
        
        for format in formats {
            var dimension: CMVideoDimensions?
            dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
//            let pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription)
            let diff = abs(targetWidth - Int(dimension?.width ?? 0)) + abs(targetHeight - Int(dimension?.height ?? 0))
            if diff < currentDiff {
                selectedFormat = format
                currentDiff = diff
            } else if diff == currentDiff {
                selectedFormat = format
            }
        }
        
        return selectedFormat
    }
    
    func selectFps(for format: AVCaptureDevice.Format?) -> Int {
        var maxFramerate = Float64(0)
        for fpsRange in format?.videoSupportedFrameRateRanges ?? [] {
            maxFramerate = Float64(fmax(Float(maxFramerate), Float(fpsRange.maxFrameRate)))
        }
        return Int(maxFramerate)
    }
    
    func findDevice(_ position: AVCaptureDevice.Position) -> AVCaptureDevice {
        let devices = RTCCameraVideoCapturer.captureDevices()
        for device in devices {
            if device.position == position {
                return device
            }
        }
        return devices[0]
    }
    
    func updateLocalVideoTrack(_ localVideoTrack: RTCVideoTrack!) {
        guard localVideoTrack != self.localVideoTrack else { return }
        self.localVideoTrack = localVideoTrack
    }
    
    func updateLocalViewCaptureTrack(_ localCapturer: RTCCameraVideoCapturer) {
        guard localCapturer != self.localView.captureSession else { return }
        localView.captureSession = localCapturer.captureSession
        self.localCapturer = localCapturer
    }
    
    func updateRemoteVideoTrack(_ remoteVideoTrack: RTCVideoTrack!) {
        guard remoteVideoTrack != self.remoteVideoTrack else { return }
        self.remoteVideoTrack?.remove(remoteView)
        remoteView.renderFrame(nil)
        self.remoteVideoTrack = remoteVideoTrack
        remoteVideoTrack.add(remoteView)
    }
}

extension CallsModuleImp: TelemedConnectionServiceProtocolDelegate {
    func returnLocalVideo(video: RTCVideoTrack?) { } // deprecated
    
    func changeTelemedState(state: TelemedState) {
        switch state {
        case .connect:
            stateTelemedConnect.onNext(1)
        case .disconnect:
            stateTelemedConnect.onNext(0)
        case .connectioning, .leaving:
            break
        }
    }
    
//    func returnLocalVideo(video: RTCVideoTrack?) {
//        updateLocalVideoTrack(video!)
//    }
    
    func returnRemoteVideo(video: RTCVideoTrack?) {
        updateRemoteVideoTrack(video!)
    }
    
    func returnTelemedError(error: Error?) {
        errorInVideoConnect.onNext(error)
    }
}

// MARK: Speaker
extension CallsModuleImp {
    
    func makeSpeakerEnable() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.overrideOutputAudioPort(.speaker)
        } catch _ {
        }
    }
    
    func makeSpeakerDisable() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.overrideOutputAudioPort(.none)
        } catch _ {
        }
    }
}
