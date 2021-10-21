/*
 *  Copyright 2016 The WebRTC Project Authors. All rights reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */
@import WebRTC;

#import "ARDSettingsModel+Private.h"
#import "ARDSettingsStore.h"
#import "WebRTC/RTCMediaConstraints.h"
#import "WebRTC/RTCCameraVideoCapturer.h"
#import "WebRTC/RTCDefaultVideoEncoderFactory.h"

NS_ASSUME_NONNULL_BEGIN
@interface ARDSettingsModel () {
	ARDSettingsStore *_settingsStore;
}
@end
@implementation ARDSettingsModel
- (NSArray<NSString *> *)availableVideoResolutions {
	NSMutableSet<NSArray<NSNumber *> *> *resolutions =
	[[NSMutableSet<NSArray<NSNumber *> *> alloc] init];
	for (AVCaptureDevice *device in [RTC_OBJC_TYPE(RTCCameraVideoCapturer) captureDevices]) {
		for (AVCaptureDeviceFormat *format in
			 [RTC_OBJC_TYPE(RTCCameraVideoCapturer) supportedFormatsForDevice:device]) {
			CMVideoDimensions resolution =
			CMVideoFormatDescriptionGetDimensions(format.formatDescription);
			NSArray<NSNumber *> *resolutionObject = @[ @(resolution.width), @(resolution.height) ];
			[resolutions addObject:resolutionObject];
		}
	}
	NSArray<NSArray<NSNumber *> *> *sortedResolutions =
	[[resolutions allObjects] sortedArrayUsingComparator:^NSComparisonResult(
																			 NSArray<NSNumber *> *obj1, NSArray<NSNumber *> *obj2) {
		NSComparisonResult cmp = [obj1.firstObject compare:obj2.firstObject];
		if (cmp != NSOrderedSame) {
			return cmp;
		}
		return [obj1.lastObject compare:obj2.lastObject];
	}];
	NSMutableArray<NSString *> *resolutionStrings = [[NSMutableArray<NSString *> alloc] init];
	for (NSArray<NSNumber *> *resolution in sortedResolutions) {
		NSString *resolutionString =
		[NSString stringWithFormat:@"%@x%@", resolution.firstObject, resolution.lastObject];
		[resolutionStrings addObject:resolutionString];
	}
	return [resolutionStrings copy];
}
- (NSString *)currentVideoResolutionSettingFromStore {
	[self registerStoreDefaults];
	return [[self settingsStore] videoResolution];
}
- (BOOL)storeVideoResolutionSetting:(NSString *)resolution {
	if (![[self availableVideoResolutions] containsObject:resolution]) {
		return NO;
	}
	[[self settingsStore] setVideoResolution:resolution];
	return YES;
}
- (NSArray<RTC_OBJC_TYPE(RTCVideoCodecInfo) *> *)availableVideoCodecs {
	return [RTC_OBJC_TYPE(RTCDefaultVideoEncoderFactory) supportedCodecs];
}
- (RTC_OBJC_TYPE(RTCVideoCodecInfo) *)currentVideoCodecSettingFromStore {
	[self registerStoreDefaults];
	NSData *codecData = [[self settingsStore] videoCodec];
	Class expectedClass = [RTC_OBJC_TYPE(RTCVideoCodecInfo) class];
	NSError *error;
	RTC_OBJC_TYPE(RTCVideoCodecInfo) *videoCodecSetting =
	[NSKeyedUnarchiver unarchivedObjectOfClass:expectedClass fromData:codecData error:&error];
	if (!error) {
		return videoCodecSetting;
	}
	return nil;
}
- (BOOL)storeVideoCodecSetting:(RTC_OBJC_TYPE(RTCVideoCodecInfo) *)videoCodec {
	if (![[self availableVideoCodecs] containsObject:videoCodec]) {
		return NO;
	}
	NSError *error;
	NSData *codecData = [NSKeyedArchiver archivedDataWithRootObject:videoCodec
											  requiringSecureCoding:NO
															  error:&error];
	if (!error) {
		[[self settingsStore] setVideoCodec:codecData];
		return YES;
	}
	return NO;
}
- (nullable NSNumber *)currentMaxBitrateSettingFromStore {
	[self registerStoreDefaults];
	return [[self settingsStore] maxBitrate];
}
- (void)storeMaxBitrateSetting:(nullable NSNumber *)bitrate {
	[[self settingsStore] setMaxBitrate:bitrate];
}
- (BOOL)currentAudioOnlySettingFromStore {
	return [[self settingsStore] audioOnly];
}
- (void)storeAudioOnlySetting:(BOOL)audioOnly {
	[[self settingsStore] setAudioOnly:audioOnly];
}
- (BOOL)currentCreateAecDumpSettingFromStore {
	return [[self settingsStore] createAecDump];
}
- (void)storeCreateAecDumpSetting:(BOOL)createAecDump {
	[[self settingsStore] setCreateAecDump:createAecDump];
}
- (BOOL)currentUseManualAudioConfigSettingFromStore {
	return [[self settingsStore] useManualAudioConfig];
}
- (void)storeUseManualAudioConfigSetting:(BOOL)useManualAudioConfig {
	[[self settingsStore] setUseManualAudioConfig:useManualAudioConfig];
}
#pragma mark - Testable
- (ARDSettingsStore *)settingsStore {
	if (!_settingsStore) {
		_settingsStore = [[ARDSettingsStore alloc] init];
		[self registerStoreDefaults];
	}
	return _settingsStore;
}
- (nullable NSString *)currentVideoResolutionWidthFromStore {
  NSString *mediaConstraintFromStore = [self currentVideoResolutionSettingFromStore];

  return [self videoResolutionComponentAtIndex:0 inString:mediaConstraintFromStore];
}

- (nullable NSString *)currentVideoResolutionHeightFromStore {
  NSString *mediaConstraintFromStore = [self currentVideoResolutionSettingFromStore];
  return [self videoResolutionComponentAtIndex:1 inString:mediaConstraintFromStore];
}

#pragma mark -
- (NSString *)defaultVideoResolutionSetting {
	return [self availableVideoResolutions].firstObject;
}
- (RTC_OBJC_TYPE(RTCVideoCodecInfo) *)defaultVideoCodecSetting {
	return [self availableVideoCodecs].firstObject;
}
- (nullable NSString *)videoResolutionComponentAtIndex:(int)index inString:(NSString *)resolution {
	if (index != 0 && index != 1) {
		return nil;
	}
	NSArray<NSString *> *components = [resolution componentsSeparatedByString:@"x"];
	if (components.count != 2) {
		return nil;
	}
	return components[index];
}
- (void)registerStoreDefaults {
	NSError *error;
	NSData *codecData = [NSKeyedArchiver archivedDataWithRootObject:[self defaultVideoCodecSetting]
											  requiringSecureCoding:NO
															  error:&error];
	if (!error) {
		[ARDSettingsStore setDefaultsForVideoResolution:[self defaultVideoResolutionSetting]
											 videoCodec:codecData
												bitrate:nil
											  audioOnly:YES
										  createAecDump:NO
								   useManualAudioConfig:YES];
	}
}

#pragma mark - Conversion to RTCMediaConstraints

- (nullable NSDictionary *)currentMediaConstraintFromStoreAsRTCDictionary {
  NSDictionary *mediaConstraintsDictionary = nil;

  NSString *widthConstraint = [self currentVideoResolutionWidthFromStore];
  NSString *heightConstraint = [self currentVideoResolutionHeightFromStore];
  if (widthConstraint && heightConstraint) {
	mediaConstraintsDictionary = @{
//      kRTCMediaConstraintsMinWidth : widthConstraint,
//      kRTCMediaConstraintsMinHeight : heightConstraint
	};
  }
  return mediaConstraintsDictionary;
}
@end
NS_ASSUME_NONNULL_END