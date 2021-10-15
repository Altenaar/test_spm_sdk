//
//  WebRTCCallService.swift
//  DRsdk
//
//  Created by Artem Ermochenko on 9/8/21.
//

import Foundation
import WebRTC
import SMPFrameworkRGSObjective

struct WebRTCCallConfiguration {
    struct WebRTCCallTURN {
        var urls: [String]
        var username: String
        var credential: String
    }
    
    var useMediaServer: Bool = true
    var webSocketURL: String
    var serverHostURL: String
    var roomId: String?
    var wssURL: String
    var clientId: String?
    var turnConfig: WebRTCCallTURN
    var isAudioOnly: Bool = false
    
    init(useMediaServer: Bool = true,
         webSocketURL: String,
         serverHostURL: String,
         roomId: String?,
         wssURL: String,
         clientId: String?,
         turnConfig: WebRTCCallTURN,
         isAudioOnly: Bool) {
        self.useMediaServer = useMediaServer
        self.webSocketURL = webSocketURL
        self.serverHostURL = serverHostURL
        self.roomId = roomId
        self.wssURL = wssURL
        self.clientId = clientId
        self.turnConfig = turnConfig
        self.isAudioOnly = isAudioOnly
    }
}

protocol WebRTCCallServiceProtocol: AnyObject {
    func webRTCClientReady()
    func didChangeICEConnectionState(_ service: WebRTCCallService, state: RTCIceConnectionState)
    func didCreateLocalCapturer(_ service: WebRTCCallService, localCapturer: RTCCameraVideoCapturer)
    func didReciveLocalVideoTrack(_ service: WebRTCCallService, localVideoTrack: RTCVideoTrack)
    func didReciveRemoteVideoTrack(_ service: WebRTCCallService, remoteVideoTrack: RTCVideoTrack)
    func didError(_ service: WebRTCCallService, error: Error)
    func needReconnect()
}

class WebRTCCallService: NSObject {
    
    private let kARDMediaStreamId = "ARDAMS"
    private let kARDAudioTrackId = "ARDAMSa0"
    private let kARDVideoTrackId = "ARDAMSv0"
    private let kARDVideoTrackKind = "video"
    
    private let kARDAppClientErrorDomain = "ARDAppClient"
    private let kARDAppClientErrorUnknown = -1
    private let kARDAppClientErrorRoomFull = -2
    private let kARDAppClientErrorCreateSDP = -3
    private let kARDAppClientErrorSetSDP = -4
    private let kARDAppClientErrorInvalidClient = -5
    private let kARDAppClientErrorInvalidRoom = -6
    
    private let kKbpsMultiplier = 1000
    
    weak var delegate: WebRTCCallServiceProtocol?
    private let factory = RTCPeerConnectionFactory()
    private var peerConnection: RTCPeerConnection!
    private let peerConstraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                                      optionalConstraints: ["DtlsSrtpKeyAgreement" : "true"])
    private let constraints = RTCMediaConstraints(mandatoryConstraints: [kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
                                                                         kRTCMediaConstraintsOfferToReceiveVideo : kRTCMediaConstraintsValueTrue],
                                                  optionalConstraints: nil)
    
    private var iceServers: [RTCIceServer]!
    private var configuration: WebRTCCallConfiguration
    
    private var outboundStream: RTCMediaStream!
    private var inboundStream: RTCMediaStream?
    private var remoteICECandidates = [RTCIceCandidate]()
    
    private var webSocket: ARDWebSocketChannel!
    
    init(config: WebRTCCallConfiguration) {
        self.configuration = config
        super.init()
        configure(config)
    }
    
    func configure(_ config: WebRTCCallConfiguration) {
        iceServers = [defaultTURNServer(urls: config.turnConfig.urls, username: config.turnConfig.username, credential: config.turnConfig.credential)]
        registerSocket()
        setupPeerConnectionIfNeeded()
        if config.isAudioOnly {
            RTCAudioSession.sharedInstance().useManualAudio = true
            RTCAudioSession.sharedInstance().isAudioEnabled = false
        }
        print(iceServers ?? "kek")
    }
    
    func handleCall() {
        
        setupPeerConnectionIfNeeded()
    }
}

// InHood functions
extension WebRTCCallService {
    
    // Register socket
    func registerSocket() {
        if webSocket == nil {
            webSocket = ARDWebSocketChannel(url: URL(string: configuration.wssURL),
                                            restURL: URL(string: configuration.webSocketURL),
                                            delegate: self)
        }
        webSocket.register(forRoomId: configuration.roomId ?? "", clientId: configuration.clientId ?? "")
    }
    
    // Default turn server
    func defaultTURNServer(urls: [String], username: String, credential: String) -> RTCIceServer {
        RTCIceServer(urlStrings: urls, username: username, credential: credential)
    }
    
    func setupPeerConnectionIfNeeded() {
        if let _ = self.peerConnection {
            self.peerConnection.offer(for: self.constraints) { (desc, error) in
                if let desc = desc {
                    print("Offer created")
                    self.peerConnection(self.peerConnection, didCreate: desc, error: error)
                }
            }
        } else {
            let rtcConfig = RTCConfiguration()
            rtcConfig.iceServers = iceServers
            rtcConfig.sdpSemantics = .unifiedPlan
            peerConnection = factory.peerConnection(with: rtcConfig, constraints: peerConstraints, delegate: self)
            print("Peer connection setted")
            
            outboundStream = factory.mediaStream(withStreamId: kARDMediaStreamId)
            let videoSource = factory.videoSource()
//            if !configuration.isAudioOnly {
                let capturer = RTCCameraVideoCapturer(delegate: videoSource)
                delegate?.didCreateLocalCapturer(self, localCapturer: capturer)
                let localVideoTrack: RTCVideoTrack = factory.videoTrack(with: videoSource, trackId: "video")
//                outboundStream.addVideoTrack(localVideoTrack)
            peerConnection.add(localVideoTrack, streamIds: [kARDMediaStreamId])
                delegate?.didReciveLocalVideoTrack(self, localVideoTrack: localVideoTrack)
//            }
//            let videoSource = factory.avFoundationVideoSource(with: constraints)
//            let videoTrack = self.factory.videoTrack(with: videoSource, trackId: "video")
//            self.outboundStream.addVideoTrack(videoTrack)
            let audioSource = self.factory.audioSource(with: self.constraints)
            let audioTrack = self.factory.audioTrack(with: audioSource, trackId: "audio")
//            self.outboundStream.addAudioTrack(audioTrack)
            peerConnection.add(audioTrack, streamIds: [kARDMediaStreamId])
//            self.peerConnection.add(self.outboundStream)
        }
    }
    
    func activateSession(_ audioSession: AVAudioSession) {
        configureAudioSession()
        RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
    }
    
    private func configureAudioSession() {
        RTCAudioSession.sharedInstance().lockForConfiguration()
        do {
            try RTCAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord.rawValue)
            try RTCAudioSession.sharedInstance().setMode(AVAudioSession.Mode.voiceChat.rawValue)
        } catch let error {
            debugPrint("Error changeing AVAudioSession category: \(error)")
        }
        RTCAudioSession.sharedInstance().unlockForConfiguration()
        RTCAudioSession.sharedInstance().isAudioEnabled = true
    }
    
    func deactivateSession(_ audioSession: AVAudioSession) {
        RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
    }
}

private extension WebRTCCallService {
    
    func setMaxBitrateForPeerConnectionVideoSender() {
        for sender in peerConnection.senders {
            if let track = sender.track,
               track.kind == kARDVideoTrackKind {
                
            }
        }
    }
    
    func setMaxBitrate(_ maxBitrate: NSNumber, sender: RTCRtpSender) {
        guard maxBitrate.intValue <= 0 else { return }
        
        let params: RTCRtpParameters = sender.parameters
        for encoding in params.encodings {
            encoding.maxBitrateBps = NSNumber(value: maxBitrate.intValue * kKbpsMultiplier)
        }
        sender.parameters = params
    }
    
//    - (void)setMaxBitrateForPeerConnectionVideoSender {
//        for (RTCRtpSender *sender in _peerConnection.senders) {
//            if (sender.track != nil) {
//                if ([sender.track.kind isEqualToString:kARDVideoTrackKind]) {
//                    [self setMaxBitrate:_maxBitrate forVideoSender:sender];
//                }
//            }
//        }
//    }
//
//    - (void)setMaxBitrate:(NSNumber *)maxBitrate forVideoSender:(RTCRtpSender *)sender {
//        if (maxBitrate.intValue <= 0) {
//            return;
//        }
//
//        RTCRtpParameters *parametersToModify = sender.parameters;
//        for (RTCRtpEncodingParameters *encoding in parametersToModify.encodings) {
//            encoding.maxBitrateBps = @(maxBitrate.intValue * kKbpsMultiplier);
//        }
//        [sender setParameters:parametersToModify];
//    }
}

extension WebRTCCallService: ARDSignalingChannelDelegate {
    func channel(_ channel: ARDSignalingChannel!, didChange state: ARDSignalingChannelState) {
        switch state {
        case .open, .registered:
            break
        case .error, .closed:
            delegate?.needReconnect()
        @unknown default:
            print("Unknown...")
        }
    }
    
    func channel(_ channel: ARDSignalingChannel!, didReceive message: ARDSignalingMessage!) {
        switch message.type {
        case kARDSignalingMessageTypeOffer, kARDSignalingMessageTypeAnswer:
            if let sdpMessage = message as? ARDSessionDescriptionMessage {
//                let description = sdpMessage.sessionDescription ?? RTCSessionDescription(type: .answer, sdp: "")
                guard let description = sdpMessage.sessionDescription else { return }
                peerConnection.setRemoteDescription(description) { error in
                    self.peerConnection(self.peerConnection, didSet: error)
                }
            }
        case kARDSignalingMessageTypeCandidate:
            if let candidateMessage = message as? ARDICECandidateMessage {
                peerConnection.add(candidateMessage.candidate)
            }
        case kARDSignalingMessageTypeCandidateRemoval:
            if let candidateMessage = message as? ARDICECandidateRemovalMessage {
                peerConnection.remove(candidateMessage.candidates)
            }
        case kARDSignalingMessageTypeBye:
            print("------Send byezzzz------")
        default:
            print()
        }
    }
}

extension WebRTCCallService: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("Signaling state changed: \(stateChanged.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        inboundStream = stream
        if let video = stream.videoTracks.first {
            delegate?.didReciveRemoteVideoTrack(self, remoteVideoTrack: video)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("ICE Connection state: \(newState.rawValue)")
        delegate?.didChangeICEConnectionState(self, state: newState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("ICE Gathering state: \(newState.rawValue)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("\(candidate)")
        let message = ARDICECandidateMessage(candidate: candidate)
        if let client = webSocket {
            client.send(message)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        let message = ARDICECandidateRemovalMessage(removedCandidates: candidates)
        if let client = webSocket {
            client.send(message)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        
    }
    
    private func peerConnection(_ peerConnection: RTCPeerConnection, didSet sessionDescriptionWithError: Error?) {
        if let error = sessionDescriptionWithError {
            print("Failed to set session description. Error: \(error)")
            let userInfo = [NSLocalizedDescriptionKey: "Failed to set session description."]
            let sdpError = NSError(domain: kARDAppClientErrorDomain,
                                   code: kARDAppClientErrorCreateSDP,
                                   userInfo: userInfo)
            delegate?.didError(self, error: sdpError)
            return
        }
        if let peerConnection = self.peerConnection,
           peerConnection.localDescription == nil {
            self.peerConnection.answer(for: self.constraints) { sdp, error in
                if let sdp = sdp {
                    self.peerConnection(self.peerConnection,
                                        didCreate: sdp,
                                        error: error)
                }
            }
        }
    }
    
    private func peerConnection(_ peerConnection: RTCPeerConnection, didCreate sessionDescription: RTCSessionDescription, error: Error?) {
        if let error = error {
            print("Failed to create session description. Error: \(error)")
            let userInfo = [NSLocalizedDescriptionKey: "Failed to create session description."]
            let sdpError = NSError(domain: kARDAppClientErrorDomain,
                                   code: kARDAppClientErrorCreateSDP,
                                   userInfo: userInfo)
            delegate?.didError(self, error: sdpError)
            return
        }
        
        peerConnection.setLocalDescription(sessionDescription) { error in
            print(error?.localizedDescription ?? "KEK")
            self.peerConnection(self.peerConnection,
                                didSet: error)
        }
        let message = ARDSessionDescriptionMessage(description: sessionDescription)
        // send to socket
        if let channel = webSocket {
            channel.send(message)
        }
        self.setMaxBitrateForPeerConnectionVideoSender()
//        _weak ARDAppClient *weakSelf = self;
//            [self.peerConnection setLocalDescription:sdp
//                                   completionHandler:^(NSError *error) {
//                                     ARDAppClient *strongSelf = weakSelf;
//                                     [strongSelf peerConnection:strongSelf.peerConnection
//                                         didSetSessionDescriptionWithError:error];
//                                   }];
//            ARDSessionDescriptionMessage *message =
//                [[ARDSessionDescriptionMessage alloc] initWithDescription:sdp];
//            [self sendSignalingMessage:message];
    }
}
