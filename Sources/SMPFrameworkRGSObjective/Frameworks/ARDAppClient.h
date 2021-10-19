/*
 *  Copyright 2014 The WebRTC Project Authors. All rights reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */
@import WebRTC;

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "WebRTC/RTCPeerConnection.h"
#import "WebRTC/RTCVideoTrack.h"
#import "WebRTC/RTCCameraVideoCapturer.h"
#import "WebRTC/RTCAudioSession.h"

typedef NS_ENUM(NSInteger, ARDAppClientState) {
  // Disconnected from servers.
  kARDAppClientStateDisconnected,
  // Connecting to servers.
  kARDAppClientStateConnecting,
  // Connected to servers.
  kARDAppClientStateConnected,
};

@class ARDAppClient;
@class ARDSettingsModel;
@class RTCMediaConstraints;

// The delegate is informed of pertinent events and will be called on the
// main queue.
@protocol ARDAppClientDelegate <NSObject>

- (void)reconnectNeed;

- (void)callDoctor;

- (void)needLeave;

- (void)appClient:(ARDAppClient *)client
    didChangeState:(ARDAppClientState)state;

- (void)appClient:(ARDAppClient *)client
    didChangeConnectionState:(RTCIceConnectionState)state;

- (void)appClient:(ARDAppClient *)client
    didReceiveLocalVideoTrack:(RTCVideoTrack *)localVideoTrack;

- (void)appClient:(ARDAppClient *)client
    didReceiveRemoteVideoTrack:(RTCVideoTrack *)remoteVideoTrack;

- (void)appClient:(ARDAppClient *)client
         didError:(NSError *)error;

- (void)appClient:(ARDAppClient *)client
      didGetStats:(NSArray *)stats;

- (void)appClient:(ARDAppClient *)client
	  didCreateLocalCapturer:(RTCCameraVideoCapturer *)localCapturer;

@end

// Handles connections to the AppRTC server for a given room. Methods on this
// class should only be called from the main queue.
@interface ARDAppClient : NSObject<RTCAudioSessionDelegate>

// If |shouldGetStats| is true, stats will be reported in 1s intervals through
// the delegate.
@property(nonatomic, assign) BOOL shouldGetStats;
@property(nonatomic, readonly) ARDAppClientState state;
@property(nonatomic, weak) id<ARDAppClientDelegate> delegate;
// Convenience constructor since all expected use cases will need a delegate
// in order to receive remote tracks.
- (instancetype)initWithDelegate:(id<ARDAppClientDelegate>)delegate;

// Sets camera constraints.
- (void)setCameraConstraints:(RTCMediaConstraints *)mediaConstraints;

// Sets maximum bitrate the rtp sender should use.
- (void)setMaxBitrate:(NSNumber *)maxBitrate;

// Establishes a connection with the AppRTC servers for the given room id.
// If |isLoopback| is true, the call will connect to itself.
// If |isAudioOnly| is true, video will be disabled for the call.
// If |shouldMakeAecDump| is true, an aecdump will be created for the call.
// If |shouldUseLevelControl| is true, the level controller will be used
// in the call.

/*- (void)connectToRoomWithId:(NSString *)roomId
                 isLoopback:(BOOL)isLoopback
                isAudioOnly:(BOOL)isAudioOnly
          shouldMakeAecDump:(BOOL)shouldMakeAecDump
      shouldUseLevelControl:(BOOL)shouldUseLevelControl;*/



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
			  settingsStore:(ARDSettingsModel *)settingsStore;

// Disconnects from the AppRTC servers and any connected clients.
- (void)disconnect:(BOOL) withoutBye;
- (void)disconnectDealloc;
- (void)callUp;
- (void)sendBye;

- (void)muteAudioIn;
- (void)unmuteAudioIn;
- (void)muteVideoIn;
- (void)unmuteVideoIn;
- (void)createLocalVideo;

- (void)setAudioCall:(BOOL)audioCall;
- (void)registerWithColliderIfReady;

- (void)setActiveAudioSession:(AVAudioSession *)session;
- (void)setDeactivateAudioSession:(AVAudioSession *)session;
- (void)needConfigureAudio;
- (void)setupVideoSender;

@end
