/*
 *  Copyright 2014 The WebRTC Project Authors. All rights reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import "ARDAppClient+Internal.h"
#import <AVFoundation/AVFoundation.h>

//#import "WebRTC/RTCAVFoundationVideoSource.h"
#import "WebRTC/RTCAudioTrack.h"
#import "WebRTC/RTCConfiguration.h"
#import "WebRTC/RTCFileLogger.h"
#import "WebRTC/RTCIceServer.h"
#import "WebRTC/RTCLogging.h"
#import "WebRTC/RTCMediaConstraints.h"
#import "WebRTC/RTCMediaStream.h"
#import "WebRTC/RTCPeerConnectionFactory.h"
#import "WebRTC/RTCRtpSender.h"
#import "WebRTC/RTCTracing.h"
#import "WebRTC/RTCAudioSession.h"
#import "WebRTC/RTCCameraVideoCapturer.h"

#import "ARDAppEngineClient.h"
#import "ARDTURNClient+Internal.h"
#import "ARDJoinResponse.h"
#import "ARDMessageResponse.h"
#import "ARDSDPUtils.h"
#import "ARDSignalingMessage.h"
#import "ARDUtilities.h"
#import "ARDWebSocketChannel.h"
#import "RTCIceCandidate+JSON.h"
#import "RTCSessionDescription+JSON.h"

static NSString * const kARDIceServerRequestUrl = @"https://appr.tc/params";

static NSString * const kARDAppClientErrorDomain = @"ARDAppClient";
static NSInteger const kARDAppClientErrorUnknown = -1;
static NSInteger const kARDAppClientErrorRoomFull = -2;
static NSInteger const kARDAppClientErrorCreateSDP = -3;
static NSInteger const kARDAppClientErrorSetSDP = -4;
static NSInteger const kARDAppClientErrorInvalidClient = -5;
static NSInteger const kARDAppClientErrorInvalidRoom = -6;
static NSString * const kARDMediaStreamId = @"ARDAMS";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";
static NSString * const kARDVideoTrackId = @"ARDAMSv0";
static NSString * const kARDVideoTrackKind = @"video";
static NSString *kARDDefaultSTUNServerUrl = @"stun:stun.l.google.com:19302";

// TODO(tkchin): Add these as UI options.
/*static BOOL const kARDAppClientEnableTracing = NO;
 static BOOL const kARDAppClientEnableRtcEventLog = YES;
 static int64_t const kARDAppClientAecDumpMaxSizeInBytes = 5e6;  // 5 MB.
 static int64_t const kARDAppClientRtcEventLogMaxSizeInBytes = 5e6; */ // 5 MB.
static int const kKbpsMultiplier = 1000;

// We need a proxy to NSTimer because it causes a strong retain cycle. When
// using the proxy, |invalidate| must be called before it properly deallocs.
@interface ARDTimerProxy : NSObject

- (instancetype)initWithInterval:(NSTimeInterval)interval
                         repeats:(BOOL)repeats
                    timerHandler:(void (^)(void))timerHandler;
- (void)invalidate;

@end

@implementation ARDTimerProxy {
    NSTimer *_timer;
    void (^_timerHandler)(void);
}

- (instancetype)initWithInterval:(NSTimeInterval)interval
                         repeats:(BOOL)repeats
                    timerHandler:(void (^)(void))timerHandler {
    NSParameterAssert(timerHandler);
    if (self = [super init]) {
        _timerHandler = timerHandler;
        _timer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                  target:self
                                                selector:@selector(timerDidFire:)
                                                userInfo:nil
                                                 repeats:repeats];
    }
    return self;
}

- (void)invalidate {
    [_timer invalidate];
}

- (void)timerDidFire:(NSTimer *)timer {
    _timerHandler();
}

@end

@implementation ARDAppClient {
    RTCFileLogger *_fileLogger;
    ARDTimerProxy *_statsTimer;
	ARDTimerProxy *_timerPing;
    RTCMediaConstraints *_cameraConstraints;
    NSNumber *_maxBitrate;
    NSMutableArray<RTCIceCandidate *> *_candidatesList;
	ARDSettingsModel *_settings;
}

@synthesize audioConnect = _audioConnect;
@synthesize shouldGetStats = _shouldGetStats;
@synthesize state = _state;
@synthesize delegate = _delegate;
@synthesize roomServerClient = _roomServerClient;
@synthesize channel = _channel;
@synthesize loopbackChannel = _loopbackChannel;
@synthesize turnClient = _turnClient;
@synthesize peerConnection = _peerConnection;
@synthesize factory = _factory;
@synthesize messageQueue = _messageQueue;
@synthesize isTurnComplete = _isTurnComplete;
@synthesize hasReceivedSdp  = _hasReceivedSdp;
@synthesize roomId = _roomId;
@synthesize clientId = _clientId;
@synthesize isInitiator = _isInitiator;
@synthesize useMediaServer = _useMediaServer;

@synthesize iceServers = _iceServers;
@synthesize webSocketURL = _websocketURL;
@synthesize webSocketRestURL = _websocketRestURL;
@synthesize defaultPeerConnectionConstraints =
_defaultPeerConnectionConstraints;
//@synthesize isLoopback = _isLoopback;
@synthesize isAudioOnly = _isAudioOnly;
@synthesize shouldMakeAecDump = _shouldMakeAecDump;
@synthesize shouldUseLevelControl = _shouldUseLevelControl;
@synthesize messageAnswer = _messageAnswer;

@synthesize defaultAudioTrack = _defaultAudioTrack;
@synthesize defaultVideoTrack = _defaultVideoTrack;

@synthesize defaultAudioSender = _defaultAudioSender;
@synthesize defaultVideoSender = _defaultVideoSender;


- (instancetype)init {
    return [self initWithDelegate:nil];
}

- (instancetype)initWithDelegate:(id<ARDAppClientDelegate>)delegate {
    if (self = [super init]) {
        _roomServerClient = [[ARDAppEngineClient alloc] init];
        _delegate = delegate;
        NSURL *turnRequestURL = [NSURL URLWithString:kARDIceServerRequestUrl];
        _turnClient = [[ARDTURNClient alloc] initWithURL:turnRequestURL];
        [self configure];
    }
    return self;
}

// TODO(tkchin): Provide signaling channel factory interface so we can recreate
// channel if we need to on network failure. Also, make this the default public
// constructor.
- (instancetype)initWithRoomServerClient:(id<ARDRoomServerClient>)rsClient
                        signalingChannel:(id<ARDSignalingChannel>)channel
                              turnClient:(id<ARDTURNClient>)turnClient
                                delegate:(id<ARDAppClientDelegate>)delegate {
    NSParameterAssert(rsClient);
    NSParameterAssert(channel);
    NSParameterAssert(turnClient);
    if (self = [super init]) {
        _roomServerClient = rsClient;
        _channel = channel;
        _turnClient = turnClient;
        _delegate = delegate;
        [self configure];
    }
    return self;
}

- (void)configure {
    _factory = [[RTCPeerConnectionFactory alloc] init];
    _messageQueue = [NSMutableArray array];
    _iceServers = [NSMutableArray array];
    _fileLogger = [[RTCFileLogger alloc] init];
    _candidatesList = [NSMutableArray array];
    [_fileLogger start];
}

- (void)dealloc {
    if (_statsTimer != nil){
        [_statsTimer invalidate];
        _statsTimer = nil;
    }
	if (_timerPing != nil){
		[_timerPing invalidate];
		_timerPing = nil;
	}
    [self disconnectDealloc];
    //self.shouldGetStats = NO;
}

- (void)setShouldGetStats:(BOOL)shouldGetStats {
    if (_shouldGetStats == shouldGetStats) {
        return;
    }
    if (shouldGetStats) {
        __weak ARDAppClient *weakSelf = self;
        _statsTimer = [[ARDTimerProxy alloc] initWithInterval:1
                                                      repeats:YES
                                                 timerHandler:^{
                                                     ARDAppClient *strongSelf = weakSelf;
                                                     [strongSelf.peerConnection statsForTrack:nil
                                                                             statsOutputLevel:RTCStatsOutputLevelDebug
                                                                            completionHandler:^(NSArray *stats) {
                                                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                                                    ARDAppClient *strongSelf = weakSelf;
                                                                                    [strongSelf.delegate appClient:strongSelf didGetStats:stats];
                                                                                });
                                                                            }];
                                                 }];
    } else {
        [_statsTimer invalidate];
        _statsTimer = nil;
    }
    _shouldGetStats = shouldGetStats;
}

- (void)setState:(ARDAppClientState)state {
    if (_state == state) {
        return;
    }
    _state = state;
    [_delegate appClient:self didChangeState:_state];
}


- (void)connectToRoomWith:(BOOL)useMediaServer
               webSocketURL:(NSString *)webSocketURL
              serverHostUrl:(NSString *)serverHostUrl
               unwrapRoomId:(NSString *)unwrapRoomId
                     wssUrl:(NSString *)wssUrl
                   clientId:(NSString *)clientId
              arrayTurnUrls:(NSArray *)arrayTurnUrls
               usernameTurn:(NSString *)usernameTurn
                 credential:(NSString *)credential
                isAudioOnly:(BOOL)isAudioOnly
			  settingsStore:(ARDSettingsModel *)settingsStore
{
    //[self speakerEnable:true];
    _isAudioOnly = isAudioOnly;
    _isInitiator = NO; //allways false
    _roomId = unwrapRoomId;
    self.state = kARDAppClientStateConnecting;
    _clientId = clientId;
    _isTurnComplete = YES;
    _useMediaServer = true;
	_settings = settingsStore;
	if (_isAudioOnly) {
		[RTCAudioSession sharedInstance].useManualAudio = true;
		[RTCAudioSession sharedInstance].isAudioEnabled = false;
	}
    _iceServers = [[NSMutableArray alloc]initWithObjects:[self defaultSTUNServerWithTurnUrls:arrayTurnUrls usernameTurn:usernameTurn credential:credential], nil];
    
//  _iceServers = [[NSMutableArray alloc]initWithObjects:[self defaultSTUNServer], nil];
    NSLog(@"%@",_iceServers);
    
//	/socket.io/?EIO=4&transport=websocket
//	NSString *socketUrl = [wssUrl stringByAppendingString:@"?EIO=4&transport=websocket"];
	
    self.webSocketURL = [[NSURL alloc]initWithString:wssUrl];
    _websocketRestURL = [[NSURL alloc]initWithString:webSocketURL];
    [self registerWithColliderIfReady];
    _audioConnect = isAudioOnly;
	
	__weak ARDAppClient *weakSelf = self;
	_timerPing = [[ARDTimerProxy alloc] initWithInterval:30
												  repeats:YES
											 timerHandler:^{
												 ARDAppClient *strongSelf = weakSelf;
												 [strongSelf.channel sendMessagePing];
											 }];
}

- (void)disconnect:(BOOL) withoutBye {
    
    if (_state == kARDAppClientStateDisconnected) {
        return;
    }
    if (_channel != nil) {
        if (_channel.state == kARDSignalingChannelStateRegistered && !withoutBye) {
            ARDByeMessage *byeMessage = [[ARDByeMessage alloc] init];
            [_channel sendMessage:byeMessage];
        }
        [_delegate needLeave];
    }
    _messageQueue = [NSMutableArray array];
#if defined(WEBRTC_IOS)
    [_factory stopAecDump];
    [_peerConnection stopRtcEventLog];
#endif
    [_peerConnection close];
    _peerConnection = nil;
    self.state = kARDAppClientStateDisconnected;
#if defined(WEBRTC_IOS)
    if (kARDAppClientEnableTracing) {
        RTCStopInternalCapture();
    }
#endif
}

- (void)sendBye {
    if (_state == kARDAppClientStateDisconnected) {
        return;
    }
    if (_channel != nil) {
        if (_channel.state == kARDSignalingChannelStateRegistered) {
            ARDByeMessage *byeMessage = [[ARDByeMessage alloc] init];
            [_channel sendMessage:byeMessage];
        }
        _channel = nil;
    }
}

- (void)disconnectDealloc {
    if (_state == kARDAppClientStateDisconnected) {
        return;
    }
    if (_channel != nil) {
        if (_channel.state == kARDSignalingChannelStateRegistered && _state == kARDAppClientStateConnected) {
            ARDByeMessage *byeMessage = [[ARDByeMessage alloc] init];
            [_channel sendMessage:byeMessage];
        }
        _channel = nil;
    }
    _clientId = nil;
    _roomId = nil;
    _isInitiator = NO;
    
    _hasReceivedSdp = NO;
    _messageQueue = [NSMutableArray array];
#if defined(WEBRTC_IOS)
    [_factory stopAecDump];
    [_peerConnection stopRtcEventLog];
#endif
    
    [_peerConnection close];
    _peerConnection = nil;
    //    self.state = kARDAppClientStateDisconnected;
    //    [_delegate appClient:self didChangeState:kARDAppClientStateDisconnected];
    
#if defined(WEBRTC_IOS)
    if (kARDAppClientEnableTracing) {
        RTCStopInternalCapture();
    }
#endif
}

- (void)setCameraConstraints:(RTCMediaConstraints *)mediaConstraints {
    _cameraConstraints = mediaConstraints;
}

- (void)setMaxBitrate:(NSNumber *)maxBitrate {
    _maxBitrate = maxBitrate;
}

- (void)callUp {
    
    _hasReceivedSdp = YES;
    
    if (!_useMediaServer) {
        if ([_messageQueue count] > 0) {
            [_messageQueue addObject:_messageAnswer];
        } else {
            [_messageQueue insertObject:_messageAnswer atIndex:0];
        }
    }
    
    self.state = kARDAppClientStateConnecting;
    [self startSignalingIfReady];
}

#pragma mark - ARDSignalingChannelDelegate

- (void)channel:(id<ARDSignalingChannel>)channel
didReceiveMessage:(ARDSignalingMessage *)message {
	NSLog(@"receive socket %@",message);
    if (message != NULL) {
        switch (message.type) {
            case kARDSignalingMessageTypeOffer:
                if (_useMediaServer) {
                    [_delegate callDoctor];
                }
            case kARDSignalingMessageTypeAnswer:
                
                // Offers and answers must be processed before any other message, so we
                // place them at the front of the queue.
                
                if (_useMediaServer) {
                    [_messageQueue addObject:message];
//                    [self processSignalingMessage:message];
                } else {
                    [_delegate callDoctor];
                    _messageAnswer = message;
                }
                break;
            case kARDSignalingMessageTypeCandidate:
                if (_useMediaServer) {
                    [_messageQueue addObject:message];
                }
                break;
            case kARDSignalingMessageTypeCandidateRemoval:
                [_messageQueue addObject:message];
                break;
            case kARDSignalingMessageTypeBye:
                // Disconnects can be processed immediately.
                [self processSignalingMessage:message];
                return;
        }
        [self drainMessageQueueIfReady];
    }
}

- (void)channel:(id<ARDSignalingChannel>)channel
 didChangeState:(ARDSignalingChannelState)state {
    switch (state) {
        case kARDSignalingChannelStateOpen:
            break;
        case kARDSignalingChannelStateRegistered:
            break;
        case kARDSignalingChannelStateClosed:
     
		case kARDSignalingChannelStateError:
			[self.delegate reconnectNeed];
            // TODO(tkchin): reconnection scenarios. Right now we just disconnect
            // completely if the websocket connection fails.
//            [self disconnect];
            break;
    }
}

#pragma mark - RTCPeerConnectionDelegate
// Callbacks for this delegate occur on non-main thread and need to be
// dispatched back to main queue as needed.

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeSignalingState:(RTCSignalingState)stateChanged {
    NSLog(@"Signaling state changed: %ld", (long)stateChanged);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
          didAddStream:(RTCMediaStream *)stream {
    dispatch_async(dispatch_get_main_queue(), ^{
		NSLog(@"Received %lu video tracks and %lu audio tracks",
               (unsigned long)stream.videoTracks.count,
               (unsigned long)stream.audioTracks.count);
        if (stream.videoTracks.count) {
            RTCVideoTrack *videoTrack = stream.videoTracks[0];
			[self->_delegate appClient:self didReceiveRemoteVideoTrack:videoTrack];
        }
		if (stream.audioTracks.count) {
			RTCAudioTrack *audioTrack = stream.audioTracks[0];
			NSLog(@"%@", audioTrack);
		}
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       didRemoveStream:(RTCMediaStream *)stream {
	NSLog(@"Stream was removed.");
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection {
	NSLog(@"WARNING: Renegotiation needed but unimplemented.");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceConnectionState:(RTCIceConnectionState)newState {
	NSLog(@"ICE state changed: %ld", (long)newState);
    dispatch_async(dispatch_get_main_queue(), ^{
		[self->_delegate appClient:self didChangeConnectionState:newState];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceGatheringState:(RTCIceGatheringState)newState {
	NSLog(@"ICE gathering state changed: %ld", (long)newState);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didGenerateIceCandidate:(RTCIceCandidate *)candidate {
    dispatch_async(dispatch_get_main_queue(), ^{
        ARDICECandidateMessage *message =
        [[ARDICECandidateMessage alloc] initWithCandidate:candidate];
        NSLog(@"message candidate %@",message);
        
		[self->_candidatesList addObject:candidate];
		if (self->_peerConnection != nil) {
			[self->_peerConnection addIceCandidate:candidate];
        }
        [self sendSignalingMessage:message];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates {
    dispatch_async(dispatch_get_main_queue(), ^{
        ARDICECandidateRemovalMessage *message =
        [[ARDICECandidateRemovalMessage alloc]
         initWithRemovedCandidates:candidates];
        [self sendSignalingMessage:message];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didOpenDataChannel:(RTCDataChannel *)dataChannel {
}

#pragma mark - RTCSessionDescriptionDelegate
// Callbacks for this delegate occur on non-main thread and need to be
// dispatched back to main queue as needed.

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp
                 error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
			NSLog(@"Failed to create session description. Error: %@", error);
            //[self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to create session description.",
                                       };
            NSError *sdpError =
            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                       code:kARDAppClientErrorCreateSDP
                                   userInfo:userInfo];
			[self->_delegate appClient:self didError:sdpError];
            return;
        }
        // Prefer H264 if available.
        RTCSessionDescription *sdpPreferringH264 =
        [ARDSDPUtils descriptionForDescription:sdp
                           preferredVideoCodec:@"H264"];
        __weak ARDAppClient *weakSelf = self;
		if (self->_peerConnection != nil) {
			[self->_peerConnection setLocalDescription:sdpPreferringH264
                               completionHandler:^(NSError *error) {
                                   ARDAppClient *strongSelf = weakSelf;
                                   [strongSelf peerConnection:strongSelf.peerConnection
                            didSetSessionDescriptionWithError:error];
                               }];
        }
        ARDSessionDescriptionMessage *message =
        [[ARDSessionDescriptionMessage alloc]
         initWithDescription:sdpPreferringH264];
        [self sendSignalingMessage:message];
        [self setMaxBitrateForPeerConnectionVideoSender];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection

didSetSessionDescriptionWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
			NSLog(@"Failed to set session description. Error: %@", error);
            //[self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to set session description.",
                                       };
            NSError *sdpError =
            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                       code:kARDAppClientErrorSetSDP
                                   userInfo:userInfo];
			[self->_delegate appClient:self didError:sdpError];
            return;
        }
        // If we're answering and we've just set the remote offer we need to create
        // an answer and set the local description.
		if (self->_peerConnection != nil) {
			if (!self->_isInitiator && !self->_peerConnection.localDescription && !self->_useMediaServer) {
                RTCMediaConstraints *constraints = [self defaultAnswerConstraints];
                __weak ARDAppClient *weakSelf = self;
				[self->_peerConnection answerForConstraints:constraints
                                    completionHandler:^(RTCSessionDescription *sdp,
                                                        NSError *error) {
                                        ARDAppClient *strongSelf = weakSelf;
                                        [strongSelf peerConnection:strongSelf.peerConnection
                                       didCreateSessionDescription:sdp
                                                             error:error];
                                    }];
            }
        }
    });
}

#pragma mark - Private

#if defined(WEBRTC_IOS)

- (NSString *)documentsFilePathForFileName:(NSString *)fileName {
    NSParameterAssert(fileName.length);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(
                                                         NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirPath = paths.firstObject;
    NSString *filePath =
    [documentsDirPath stringByAppendingPathComponent:fileName];
    return filePath;
}

#endif

- (BOOL)hasJoinedRoomServerRoom {
    return _clientId.length;
}

// Begins the peer connection connection process if we have both joined a room
// on the room server and tried to obtain a TURN server. Otherwise does nothing.
// A peer connection object will be created with a stream that contains local
// audio and video capture. If this client is the caller, an offer is created as
// well, otherwise the client will wait for an offer to arrive.

- (void)setAudioCall:(BOOL)audioCall {
    _audioConnect = audioCall;
}

- (void)startSignalingIfReady {
    if (!_isTurnComplete || !self.hasJoinedRoomServerRoom) {
        return;
    }
    
    // Create peer connection.
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    RTCConfiguration *config = [[RTCConfiguration alloc] init];
    config.iceServers = _iceServers;
    _peerConnection = [_factory peerConnectionWithConfiguration:config
                                                    constraints:constraints
                                                       delegate:self];
    // Create AV senders.
	[self createMediaSenders];
//    _defaultAudioSender = [self createAudioSender];
//	_defaultAudioSender.track.isEnabled = true;
//	_defaultVideoSender = [self createVideoSender];
    
    for (RTCIceCandidate *candidate in _candidatesList) {
        [_peerConnection addIceCandidate:candidate];
    }
    [_candidatesList removeAllObjects];
    
    if (_audioConnect) {
        _defaultVideoSender.track.isEnabled = NO;
    }

    if (_isInitiator) {
    } else {
        if (_useMediaServer) {
            RTCMediaConstraints *constraints = [self defaultOfferConstraints];
            __weak ARDAppClient *weakSelf = self;
            [_peerConnection offerForConstraints:constraints
                               completionHandler:^(RTCSessionDescription *sdp,
                                                   NSError *error) {
                                   ARDAppClient *strongSelf = weakSelf;
                                   [strongSelf peerConnection:strongSelf.peerConnection
                                  didCreateSessionDescription:sdp
                                                        error:error];
                               }];
        } else {
            // Check if we've received an offer.
            [self drainMessageQueueIfReady];
        }
    }
    
    self.state = kARDAppClientStateConnected;
    
#if defined(WEBRTC_IOS)
    // Start event log.
    if (kARDAppClientEnableRtcEventLog) {
        NSString *filePath = [self documentsFilePathForFileName:@"webrtc-rtceventlog"];
        if (![_peerConnection startRtcEventLogWithFilePath:filePath
                                            maxSizeInBytes:kARDAppClientRtcEventLogMaxSizeInBytes]) {
			NSLog(@"Failed to start event logging.");
        }
    }
    
    // Start aecdump diagnostic recording.
    if (_shouldMakeAecDump) {
        NSString *filePath = [self documentsFilePathForFileName:@"webrtc-audio.aecdump"];
        if (![_factory startAecDumpWithFilePath:filePath
                                 maxSizeInBytes:kARDAppClientAecDumpMaxSizeInBytes]) {
			NSLog(@"Failed to start aec dump.");
        }
    }
#endif
}

- (RTCIceServer *)defaultSTUNServerWithTurnUrls:(NSArray *)arrayTurnUrls
                                   usernameTurn:(NSString *)usernameTurn
                                     credential:(NSString *)credential
{
    
    return [[RTCIceServer alloc]initWithURLStrings:arrayTurnUrls username:usernameTurn credential:credential];
}

- (RTCIceServer *)defaultSTUNServer {
    
    /*turn:turn.doconcall.ru:3478?transport=udp',
     'turn:turn.doconcall.ru:3478?transport=tcp',
     'turn:turn.docplus.ru:3478?transport=udp',
     'turn:turn.docplus.ru:3478?transport=tcp',*/
//    return [[RTCIceServer alloc]initWithURLStrings:[[NSArray alloc]initWithObjects:@"stun:91.201.43.51:5349",
//                                                    @"stun:185.12.94.199:5349", nil]];
    return [[RTCIceServer alloc]initWithURLStrings:[[NSArray alloc]initWithObjects:kARDDefaultSTUNServerUrl, nil] username:@"" credential:@""];
}

// Processes the messages that we've received from the room server and the
// signaling channel. The offer or answer message must be processed before other
// signaling messages, however they can arrive out of order. Hence, this method
// only processes pending messages if there is a peer connection object and
// if we have received either an offer or answer.
- (void)drainMessageQueueIfReady {
    if (!_peerConnection || !_hasReceivedSdp) {
        return;
    }
    for (ARDSignalingMessage *message in _messageQueue) {
        [self processSignalingMessage:message];
    }
    [_messageQueue removeAllObjects];
}

// Processes the given signaling message based on its type.
- (void)processSignalingMessage:(ARDSignalingMessage *)message {
    //  NSParameterAssert(_peerConnection ||
    //  message.type == kARDSignalingMessageTypeBye);
    switch (message.type) {
        case kARDSignalingMessageTypeOffer:{
            if (_useMediaServer) {
                ARDSessionDescriptionMessage *sdpMessage =
                (ARDSessionDescriptionMessage *)message;
                RTCSessionDescription *description = sdpMessage.sessionDescription;
                // Prefer H264 if available.
                RTCSessionDescription *sdpPreferringH264 =
                [ARDSDPUtils descriptionForDescription:description
                                   preferredVideoCodec:@"H264"];
                __weak ARDAppClient *weakSelf = self;
                if (_peerConnection != nil) {
                    [_peerConnection setRemoteDescription:sdpPreferringH264
                                        completionHandler:^(NSError *error) {
                                            ARDAppClient *strongSelf = weakSelf;
                                            [strongSelf peerConnection:strongSelf.peerConnection
                                     didSetSessionDescriptionWithError:error];
                                        }];
                }
                break;
            }
        }
        case kARDSignalingMessageTypeAnswer: {
            ARDSessionDescriptionMessage *sdpMessage =
            (ARDSessionDescriptionMessage *)message;
            RTCSessionDescription *description = sdpMessage.sessionDescription;
            // Prefer H264 if available.
            RTCSessionDescription *sdpPreferringH264 =
            [ARDSDPUtils descriptionForDescription:description
                               preferredVideoCodec:@"H264"];
            __weak ARDAppClient *weakSelf = self;
            if (_peerConnection != nil) {
                [_peerConnection setRemoteDescription:sdpPreferringH264
                                    completionHandler:^(NSError *error) {
                                        ARDAppClient *strongSelf = weakSelf;
                                        [strongSelf peerConnection:strongSelf.peerConnection
                                 didSetSessionDescriptionWithError:error];
                                    }];
            }
            break;
        }
        case kARDSignalingMessageTypeCandidate: {
            ARDICECandidateMessage *candidateMessage =
            (ARDICECandidateMessage *)message;
            [_candidatesList addObject:candidateMessage.candidate];
            if (_peerConnection != nil) {
                [_peerConnection addIceCandidate:candidateMessage.candidate];
            }
            break;
        }
        case kARDSignalingMessageTypeCandidateRemoval: {
            ARDICECandidateRemovalMessage *candidateMessage =
            (ARDICECandidateRemovalMessage *)message;
            if (_peerConnection != nil) {
                [_peerConnection removeIceCandidates:candidateMessage.candidates];
            }
            break;
        }
        case kARDSignalingMessageTypeBye:
            [_delegate needLeave];
            break;
    }
}

// Sends a signaling message to the other client. The caller will send messages
// through the room server, whereas the callee will send messages over the
// signaling channel.
- (void)sendSignalingMessage:(ARDSignalingMessage *)message {
    if (_isInitiator) {
        NSLog(@"sendSignalingMessage _isInitiator = true");
    } else {
        NSLog(@"sendSignalingMessage _isInitiator = false");
        if (_channel != nil) {
            NSLog(@"sendSignalingMessage sendmessage");
            [_channel sendMessage:message];
        }
    }
}

- (void)setMaxBitrateForPeerConnectionVideoSender {
    for (RTCRtpSender *sender in _peerConnection.senders) {
        if (sender.track != nil) {
            if ([sender.track.kind isEqualToString:kARDVideoTrackKind]) {
                [self setMaxBitrate:_maxBitrate forVideoSender:sender];
            }
        }
    }
}

- (void)setMaxBitrate:(NSNumber *)maxBitrate forVideoSender:(RTCRtpSender *)sender {
    if (maxBitrate.intValue <= 0) {
        return;
    }
    
    RTCRtpParameters *parametersToModify = sender.parameters;
    for (RTCRtpEncodingParameters *encoding in parametersToModify.encodings) {
        encoding.maxBitrateBps = @(maxBitrate.intValue * kKbpsMultiplier);
    }
    [sender setParameters:parametersToModify];
}

- (void)createMediaSenders {
	
//	RTCMediaStream *localStream = [_factory mediaStreamWithStreamId:kARDMediaStreamId];
	
	RTCMediaConstraints *constraints = [self defaultMediaAudioConstraints];
	RTCAudioSource *source = [_factory audioSourceWithConstraints:constraints];
	RTCAudioTrack *track = [_factory audioTrackWithSource:source
												  trackId:kARDAudioTrackId];
	_defaultAudioTrack = track;
	_defaultAudioSender = [_peerConnection addTrack:track streamIds:@[kARDMediaStreamId]];
//	[self configureAVAudioSession];
//	[localStream addAudioTrack:track];
	// Video
	RTCVideoTrack *localVideoTrack = [self createLocalVideoTrack];
	_defaultVideoSender = nil;
	if (localVideoTrack) {
		_defaultVideoSender = [_peerConnection addTrack:localVideoTrack streamIds:@[kARDMediaStreamId]];
//		[localStream addVideoTrack:localVideoTrack];
		if ([_delegate respondsToSelector:@selector(appClient:didReceiveLocalVideoTrack:)]) {
			[_delegate appClient:self didReceiveLocalVideoTrack:localVideoTrack];
		}
	}
//	[_peerConnection addStream:localStream];
}

- (void)configureAVAudioSession
{
    // Get your app's audioSession singleton object
    AVAudioSession *session = [AVAudioSession sharedInstance];

    // Error handling
    BOOL success;
    NSError *error;

    // set the audioSession category.
    // Needs to be Record or PlayAndRecord to use audioRouteOverride:

//    success = [session setCategory:AVAudioSessionCategoryPlayAndRecord
//                             error:&error];
	success = [session setCategory: AVAudioSessionCategoryPlayAndRecord
					   withOptions: AVAudioSessionCategoryOptionDefaultToSpeaker|AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionAllowBluetoothA2DP|AVAudioSessionCategoryOptionAllowAirPlay
							 error:&error];
//withOptions: AVAudioSessionCategoryOptionDefaultToSpeaker|AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionAllowBluetoothA2DP|AVAudioSessionCategoryOptionAllowAirPlay

    if (!success) {
        NSLog(@"AVAudioSession error setting category:%@",error);
    }

    // Set the audioSession override
    success = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                                         error:&error];
//	success = [session setCategory: AVAudioSessionCategoryPlayAndRecord
//					   withOptions: AVAudioSessionCategoryOptionDefaultToSpeaker|AVAudioSessionCategoryOptionAllowBluetoothA2DP|AVAudioSessionCategoryOptionAllowAirPlay
//							 error:&error];
    if (!success) {
        NSLog(@"AVAudioSession error overrideOutputAudioPort:%@",error);
    }

    // Activate the audio session
    success = [session setActive:YES error:&error];
    if (!success) {
        NSLog(@"AVAudioSession error activating: %@",error);
    }
    else {
        NSLog(@"AudioSession active");
    }
    
}

- (RTCVideoTrack *)createLocalVideoTrack {
	RTCVideoTrack *localVideoTrack = nil;
	RTCVideoSource *source = [_factory videoSource];
#if !TARGET_IPHONE_SIMULATOR
	//	if (!_isAudioOnly) {
	RTCCameraVideoCapturer *capturer =
	[[RTCCameraVideoCapturer alloc] initWithDelegate:source];
	[_delegate appClient:self didCreateLocalCapturer:capturer];
	localVideoTrack = [_factory videoTrackWithSource:source trackId:kARDVideoTrackId];
	//	}
#endif
	return localVideoTrack;
}

#pragma mark - Audio mute/unmute
- (void)muteAudioIn {
	NSLog(@"audio muted");
    _defaultAudioSender.track.isEnabled = NO;
}
- (void)unmuteAudioIn {
	NSLog(@"audio unmuted");
    _defaultAudioSender.track.isEnabled = YES;
}

#pragma mark - Video mute/unmute
- (void)muteVideoIn {
    NSLog(@"video muted");
    if (_defaultVideoSender != nil) {
        _defaultVideoSender.track.isEnabled = NO;
    }
}
- (void)unmuteVideoIn {
	NSLog(@"video unmuted");
    if (_defaultVideoSender != nil) {
        _defaultVideoSender.track.isEnabled = YES;
    }
}
- (void)createLocalVideo {
	[self createMediaSenders];
}

#pragma mark - Collider methods

- (void)registerWithColliderIfReady {
    if (!self.hasJoinedRoomServerRoom) {
        return;
    }
    // Open WebSocket connection.
    if (_channel == nil) {
        _channel =
        [[ARDWebSocketChannel alloc] initWithURL:_websocketURL
                                         restURL:_websocketRestURL
                                        delegate:self];
    }
    [_channel registerForRoomId:_roomId clientId:_clientId];
}

#pragma mark - Defaults

- (RTCMediaConstraints *)defaultMediaAudioConstraints {
	
	NSDictionary *mandatoryConstraints = @{};
	  RTCMediaConstraints *constraints =
		  [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
															   optionalConstraints:nil];
	  return constraints;
}

- (RTCMediaConstraints *)cameraConstraints {
    return _cameraConstraints;
}

- (RTCMediaConstraints *)defaultAnswerConstraints {
    return [self defaultOfferConstraints];
}

- (RTCMediaConstraints *)defaultOfferConstraints {
    NSDictionary *mandatoryConstraints = @{
                                           kRTCMediaConstraintsOfferToReceiveAudio : @"true",
										   kRTCMediaConstraintsOfferToReceiveVideo : @"true"
                                           };
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:mandatoryConstraints
     optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    if (_defaultPeerConnectionConstraints) {
        return _defaultPeerConnectionConstraints;
    }
    NSString *value = @"true";
    NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : value };
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
     optionalConstraints:optionalConstraints];
    return constraints;
}

#pragma mark - Errors

+ (NSError *)errorForJoinResultType:(ARDJoinResultType)resultType {
    NSError *error = nil;
    switch (resultType) {
        case kARDJoinResultTypeSuccess:
            break;
        case kARDJoinResultTypeUnknown: {
            error = [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                               code:kARDAppClientErrorUnknown
                                           userInfo:@{
                                                      NSLocalizedDescriptionKey: @"Unknown error.",
                                                      }];
            break;
        }
        case kARDJoinResultTypeFull: {
            error = [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                               code:kARDAppClientErrorRoomFull
                                           userInfo:@{
                                                      NSLocalizedDescriptionKey: @"Room is full.",
                                                      }];
            break;
        }
    }
    return error;
}

+ (NSError *)errorForMessageResultType:(ARDMessageResultType)resultType {
    NSError *error = nil;
    switch (resultType) {
        case kARDMessageResultTypeSuccess:
            break;
        case kARDMessageResultTypeUnknown:
            error = [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                               code:kARDAppClientErrorUnknown
                                           userInfo:@{
                                                      NSLocalizedDescriptionKey: @"Unknown error.",
                                                      }];
            break;
        case kARDMessageResultTypeInvalidClient:
            error = [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                               code:kARDAppClientErrorInvalidClient
                                           userInfo:@{
                                                      NSLocalizedDescriptionKey: @"Invalid client.",
                                                      }];
            break;
        case kARDMessageResultTypeInvalidRoom:
            error = [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                               code:kARDAppClientErrorInvalidRoom
                                           userInfo:@{
                                                      NSLocalizedDescriptionKey: @"Invalid room.",
                                                      }];
            break;
    }
    return error;
}

- (void)setActiveAudioSession:(AVAudioSession *)session {
	RTCAudioSession *audioSession = [RTCAudioSession sharedInstance];
	[audioSession audioSessionDidActivate:session];
	audioSession.isAudioEnabled = true;
	NSLog(@"Audio session isActive: %d\nAudio session isEnabled: %d", [audioSession isActive], [audioSession isAudioEnabled]);
}

- (void)setDeactivateAudioSession:(AVAudioSession *)session {
	NSError *error;
	[[RTCAudioSession sharedInstance] audioSessionDidDeactivate:session];
	[[RTCAudioSession sharedInstance] setActive:false error:&error];
}

- (void)needConfigureAudio {
	NSError *error;
	RTCAudioSession *audioSession = [RTCAudioSession sharedInstance];
	[audioSession lockForConfiguration];
	[audioSession setUseManualAudio:true];
	[audioSession setIsAudioEnabled:false];
	[audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
				  withOptions:AVAudioSessionCategoryOptionAllowBluetooth|AVAudioSessionCategoryOptionAllowBluetoothA2DP|AVAudioSessionCategoryOptionAllowAirPlay
						error:&error];
	[audioSession setMode:AVAudioSessionModeVoiceChat
					error:&error];
	[audioSession unlockForConfiguration];
}

- (void)audioSessionDidChangeRoute:(RTCAudioSession *)session reason:(AVAudioSessionRouteChangeReason)reason previousRoute:(AVAudioSessionRouteDescription *)previousRoute {
	NSLog(@"%@, %lu, %@", session, (unsigned long)reason, previousRoute);
}

- (void)audioSessionDidStartPlayOrRecord:(RTCAudioSession *)session {
	NSLog(@"Activate session: %@", session);
}

- (void)audioSessionDidStopPlayOrRecord:(RTCAudioSession *)session {
	NSLog(@"Deactivate session: %@", session);
}
	
- (void)setupVideoSender {
	_defaultVideoTrack = [self createLocalVideoTrack];
}

@end
