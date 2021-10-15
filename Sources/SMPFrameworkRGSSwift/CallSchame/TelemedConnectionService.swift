import Foundation
import CoreTelephony
import SMPFrameworkRGSObjective

enum TelemedState {
    case connect
    case disconnect
    case connectioning
    case leaving
}

protocol TelemedConnectionServiceProtocolDelegate {
    func changeTelemedState(state: TelemedState)
    func returnLocalVideo(video: RTCVideoTrack?)
    func returnRemoteVideo(video: RTCVideoTrack?)
    func returnTelemedError(error: Error?)
}

protocol TelemedConnectionServiceProtocol {
    
    var delegate: TelemedConnectionServiceProtocolDelegate? { get set }
    var telemedState: TelemedState { get }
    
    var localVideoCapturerCallback: (( _ capture: RTCCameraVideoCapturer?) -> Void)? { get set }
    var localVideoCapturer: RTCCameraVideoCapturer? { get }
    var localVideoTrackCallback: (( _ track: RTCVideoTrack?) -> Void)? { get set }
    var localVideoTrack: RTCVideoTrack? { get }
    var remoteVideoTrackCallback: (( _ track: RTCVideoTrack?) -> Void)? { get set }
    var remoteVideoTrack: RTCVideoTrack? { get }

    func completeTelemedCall()
    func callUpTelemed()
    func connect(isAudio: Bool)
    func reconnect()
    func muteAudioIn()
    func unmuteAudioIn()
    func muteVideoIn()
    func unmuteVideoIn()
    func callUp()
    func sendBye()
}

class TelemedConnectionService: NSObject, TelemedConnectionServiceProtocol {
    var delegate: TelemedConnectionServiceProtocolDelegate?
    private let reachability = try! Reachability()
    
    private let telemedService: TelemedServiceProtocol
    private var client: ARDAppClient?
    private let consultationID: Int?
    private var isAudio: Bool = false
    private var token: String
    var telemedState: TelemedState
    
    var localVideoCapturerCallback: (( _ capture: RTCCameraVideoCapturer?) -> Void)?
    var localVideoCapturer: RTCCameraVideoCapturer? {
        didSet {
            localVideoCapturerCallback?(localVideoCapturer)
        }
    }
    var localVideoTrackCallback: (( _ track: RTCVideoTrack?) -> Void)?
    var localVideoTrack: RTCVideoTrack? {
        didSet {
            localVideoTrackCallback?(localVideoTrack)
        }
    }
    var remoteVideoTrackCallback: (( _ track: RTCVideoTrack?) -> Void)?
    var remoteVideoTrack: RTCVideoTrack? {
        didSet {
            remoteVideoTrackCallback?(remoteVideoTrack)
        }
    }
    
    init(telemedService: TelemedServiceProtocol, consultationID: Int?, token: String) {
        self.telemedService = telemedService
        self.consultationID = consultationID
        telemedState = .disconnect
        self.token = token
        super.init()
        client = ARDAppClient(delegate: self)
        setupReachability()
    }
    
    private func setupReachability() {
        reachability.whenReachable = { [weak self] reachability in
            guard let strongSelf = self else { return }
            if strongSelf.telemedState == .disconnect {
                strongSelf.reconnect()
            }
        }
        do {
            try reachability.startNotifier()
        } catch {
            print("Unable to start notifier rechability")
        }
        
    }
    
    func connect(isAudio: Bool) {
        telemedState = .connectioning
        self.isAudio = isAudio
        //        client = ARDAppClient(delegate: self)
        guard let consultationID = consultationID else { return }
        let params = ["token": token, "consultationId": consultationID] as [String: AnyObject]
        _ = telemedService.createJoinConsultationWithParams(params, completionBlock: { [weak self] (error, consultation) in
            guard let strongSelf = self else { return }
            if let error = error {
                strongSelf.delegate?.returnTelemedError(error: error)
                return
            }
            guard let consultation = consultation, let roomId = consultation.roomId,
                  let clientId = consultation.clientId, let wssUrl = consultation.wssUrl,
                  let wssPostUrl = consultation.wssPostUrl else { return }
            
            let settingsModel = ARDSettingsModel()
            let cameraConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: settingsModel.currentMediaConstraintFromStoreAsRTCDictionary() as? [String: String])
            strongSelf.client?.setMaxBitrate(settingsModel.currentMaxBitrateSettingFromStore())
            strongSelf.client?.setCameraConstraints(cameraConstraints)
            strongSelf.client?.connectToRoom(with: consultation.useMediaServer ?? true,
                                             webSocketURL: "\(wssPostUrl)/",
                                             serverHostUrl: "\(wssUrl)/",
                                             unwrapRoomId: roomId,
                                             wssUrl: "\(wssUrl)/",
                                             clientId: clientId,
                                             arrayTurnUrls: consultation.turnServers ?? ["stun:stun.l.google.com:19302"] ,
                                             usernameTurn: consultation.usernameTurn ?? "",
                                             credential: consultation.credentialTurn ?? "",
                                             isAudioOnly: isAudio,
                                             settingsStore: settingsModel)
        })
    }
    
    func completeTelemedCall() {
        localVideoTrack = nil
        localVideoCapturer = nil
        remoteVideoTrack = nil
        delegate?.changeTelemedState(state: .disconnect)
        if telemedState == .connect {
            telemedState = .disconnect
        }
        //TO DO
        leaveRoom()
        client?.sendBye()
    }
    
    func callUpTelemed() {
        client?.callUp()
    }
    
    func reconnect() {
        if telemedState == .disconnect {
            connect(isAudio: isAudio)
        }
    }
    
    func muteAudioIn() {
        client?.muteAudioIn()
    }
    
    func unmuteAudioIn() {
        client?.unmuteAudioIn()
    }
    
    func muteVideoIn() {
        client?.muteVideoIn()
    }
    
    func unmuteVideoIn() {
        client?.unmuteVideoIn()
    }
    
    func callUp() {
        client?.callUp()
    }
    
    func sendBye() {
        localVideoTrack = nil
        localVideoCapturer = nil
        remoteVideoTrack = nil
        if telemedState == .connect {
            telemedState = .disconnect
        }
        delegate?.changeTelemedState(state: .disconnect)
        client?.sendBye()
    }
}

extension TelemedConnectionService {
    private func leaveRoom() {
        guard let consultationId = consultationID else { return }
        telemedState = .leaving
        let params = ["token": token, "consultationId": consultationId] as [String: AnyObject]
        _ = telemedService.createLeaveConsultationWithParams(params, completionBlock: { [weak self] error in
            guard let strongSelf = self else { return }
            if error != nil {
                strongSelf.delegate?.returnTelemedError(error: error)
            }
            if strongSelf.telemedState == .leaving {
                strongSelf.telemedState = .disconnect
                strongSelf.reconnect()
            }
        })
    }
}

extension TelemedConnectionService: ARDAppClientDelegate {
    func appClient(_ client: ARDAppClient!, didCreateLocalCapturer localCapturer: RTCCameraVideoCapturer!) {
        let camPosition = AVCaptureDevice.Position.front
        let device = self.findDevice(camPosition)
        let format: AVCaptureDevice.Format? = selectFormat(for: device)
        
        if format == nil {
            print("No valid formats for device %@", device)
            assert(false, "")
            
            return
        }
        
        let fps = selectFps(for: format)
        
        localCapturer.startCapture(with: device, format: format!, fps: fps)
        localVideoCapturer = localCapturer
    }
    
    func didCreateLocalCapturer(_ service: WebRTCCallService, localCapturer: RTCCameraVideoCapturer) {
        let camPosition = AVCaptureDevice.Position.front
        let device = self.findDevice(camPosition)
        let format: AVCaptureDevice.Format? = selectFormat(for: device)
        
        if format == nil {
            print("No valid formats for device %@", device)
            assert(false, "")
            
            return
        }
        
        let fps = selectFps(for: format)
        
        localCapturer.startCapture(with: device, format: format!, fps: fps)
        localVideoCapturer = localCapturer
    }
    
    func didReciveLocalVideoTrack(_ service: WebRTCCallService, localVideoTrack: RTCVideoTrack) {
        if self.localVideoTrack != localVideoTrack {
            self.localVideoTrack = localVideoTrack
        }
    }
    
    func didReciveRemoteVideoTrack(_ service: WebRTCCallService, remoteVideoTrack: RTCVideoTrack) {
        if localVideoTrack != remoteVideoTrack {
            self.remoteVideoTrack = remoteVideoTrack
        }
    }
    
    func reconnectNeed() {
        // когда не подключился ARDSignalingChannel
        sendBye()
        localVideoTrack = nil
        localVideoCapturer = nil
        remoteVideoTrack = nil
        if telemedState == .connect {
            telemedState = .disconnect
        }
        delegate?.changeTelemedState(state: .disconnect)
        leaveRoom()
    }
    
    func callDoctor() {
        telemedState = .connect
        delegate?.changeTelemedState(state: .connect)
    }
    
    func needLeave() {
        // когда нам приходит  bye с сервера
        localVideoTrack = nil
        localVideoCapturer = nil
        remoteVideoTrack = nil
        if telemedState == .connect {
            telemedState = .disconnect
        }
        delegate?.changeTelemedState(state: .disconnect)
        leaveRoom()
        client?.sendBye()
    }
    
    func appClient(_ client: ARDAppClient!, didChange state: ARDAppClientState) {
        switch state {
        case .disconnected:
            self.client?.registerWithColliderIfReady()
        default: break
        }
    }
    
    func appClient(_ client: ARDAppClient!, didChange state: RTCIceConnectionState) {
        switch state {
        case .disconnected:
            //            telemedState.value = .disconnect
            sendBye()
        default:
            break
        }
    }
    
    func appClient(_ client: ARDAppClient!, didReceiveLocalVideoTrack localVideoTrack: RTCVideoTrack!) {
        if self.localVideoTrack != localVideoTrack {
            self.localVideoTrack = localVideoTrack
        }
    }
    
    func appClient(_ client: ARDAppClient!, didReceiveRemoteVideoTrack remoteVideoTrack: RTCVideoTrack!) {
        if localVideoTrack != remoteVideoTrack {
            self.remoteVideoTrack = remoteVideoTrack
        }
    }
    
    func appClient(_ client: ARDAppClient!, didError error: Error!) {
        
    }
    
    func appClient(_ client: ARDAppClient!, didGetStats stats: [Any]!) {
        
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
}
