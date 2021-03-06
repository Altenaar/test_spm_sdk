/*
 *  Copyright 2015 The WebRTC Project Authors. All rights reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */
@import WebRTC;

#import "ARDMainViewController.h"

#import <AVFoundation/AVFoundation.h>

#import "WebRTC/RTCDispatcher.h"
#import "WebRTC/RTCLogging.h"
#import "WebRTC/RTCAudioSession.h"
//#import "webrtc/modules/audio_device/ios/objc/RTCAudioSessionConfiguration.h"

#import "ARDAppClient.h"
#import "ARDMainView.h"
#import "ARDSettingsModel.h"
#import "ARDSettingsViewController.h"
#import "ARDVideoCallViewController.h"

static NSString *const barButtonImageString = @"ic_settings_black_24dp.png";

@interface ARDMainViewController () <
    ARDMainViewDelegate,
    ARDVideoCallViewControllerDelegate
//    RTCAudioSessionDelegate>
    >
@end

@implementation ARDMainViewController {
  //ARDMainView *_mainView;
  AVAudioPlayer *_audioPlayer;
  BOOL _useManualAudio;
}

- (void)loadView {
  /*self.title = @"AppRTC Mobile";
  _mainView = [[ARDMainView alloc] initWithFrame:CGRectZero];
  _mainView.delegate = self;
  self.view = _mainView;
  [self addSettingsBarButton];*/

  [self setupAudioPlayer];
}

/*- (void)addSettingsBarButton {
  UIBarButtonItem *settingsButton =
      [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:barButtonImageString]
                                       style:UIBarButtonItemStylePlain
                                      target:self
                                      action:@selector(showSettings:)];
  self.navigationItem.rightBarButtonItem = settingsButton;
}*/

#pragma mark - ARDMainViewDelegate

- (void)mainView:(ARDMainView *)mainView
             didInputRoom:(NSString *)room
               isLoopback:(BOOL)isLoopback
              isAudioOnly:(BOOL)isAudioOnly
        shouldMakeAecDump:(BOOL)shouldMakeAecDump
    shouldUseLevelControl:(BOOL)shouldUseLevelControl
           useManualAudio:(BOOL)useManualAudio {
  if (!room.length) {
    //[self showAlertWithMessage:@"Missing room name."];
    return;
  }
  // Trim whitespaces.
  NSCharacterSet *whitespaceSet = [NSCharacterSet whitespaceCharacterSet];
  NSString *trimmedRoom = [room stringByTrimmingCharactersInSet:whitespaceSet];

  // Check that room name is valid.
  NSError *error = nil;
  NSRegularExpressionOptions options = NSRegularExpressionCaseInsensitive;
  NSRegularExpression *regex =
      [NSRegularExpression regularExpressionWithPattern:@"\\w+"
                                                options:options
                                                  error:&error];
  if (error) {
    //[self showAlertWithMessage:error.localizedDescription];
    return;
  }
  NSRange matchRange =
      [regex rangeOfFirstMatchInString:trimmedRoom
                               options:0
                                 range:NSMakeRange(0, trimmedRoom.length)];
  if (matchRange.location == NSNotFound ||
      matchRange.length != trimmedRoom.length) {
    //[self showAlertWithMessage:@"Invalid room name."];
    return;
  }

  RTCAudioSession *session = [RTCAudioSession sharedInstance];
  session.useManualAudio = TRUE;
//  session.isAudioEnabled = NO;

  // Kick off the video call.
  ARDVideoCallViewController *videoCallViewController =
      [[ARDVideoCallViewController alloc] initForRoom:trimmedRoom
                                           isLoopback:isLoopback
                                          isAudioOnly:isAudioOnly
                                    shouldMakeAecDump:shouldMakeAecDump
                                shouldUseLevelControl:shouldUseLevelControl
                                             delegate:self];
  videoCallViewController.modalTransitionStyle =
      UIModalTransitionStyleCrossDissolve;
  [self presentViewController:videoCallViewController
                     animated:YES
                   completion:nil];
}

- (void)mainViewDidToggleAudioLoop:(ARDMainView *)mainView {
  if (mainView.isAudioLoopPlaying) {
    [_audioPlayer stop];
  } else {
    [_audioPlayer play];
  }
  mainView.isAudioLoopPlaying = _audioPlayer.playing;
}

#pragma mark - ARDVideoCallViewControllerDelegate

- (void)viewControllerDidFinish:(ARDVideoCallViewController *)viewController {
  if (![viewController isBeingDismissed]) {
    RTCLog(@"Dismissing VC");
    [self dismissViewControllerAnimated:YES completion:^{
      [self restartAudioPlayerIfNeeded];
    }];
  }
}

#pragma mark - Private
- (void)showSettings:(id)sender {
  ARDSettingsViewController *settingsController =
      [[ARDSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped
                                         settingsModel:[[ARDSettingsModel alloc] init]];

  UINavigationController *navigationController =
      [[UINavigationController alloc] initWithRootViewController:settingsController];
  [self presentViewControllerAsModal:navigationController];
}

- (void)presentViewControllerAsModal:(UIViewController *)viewController {
  [self presentViewController:viewController animated:YES completion:nil];
}

- (void)setupAudioPlayer {
  NSString *audioFilePath =
      [[NSBundle mainBundle] pathForResource:@"mozart" ofType:@"mp3"];
  NSURL *audioFileURL = [NSURL URLWithString:audioFilePath];
  _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioFileURL
                                                        error:nil];
  _audioPlayer.numberOfLoops = -1;
  _audioPlayer.volume = 1.0;
  [_audioPlayer prepareToPlay];
}

- (void)restartAudioPlayerIfNeeded {
  if (!self.presentedViewController) {
    [_audioPlayer play];
  }
}

@end
