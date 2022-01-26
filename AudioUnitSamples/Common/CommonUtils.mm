//
//  CommonUtils.m
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/26.
//

#import "CommonUtils.h"

@implementation CommonUtils

+ (AudioStreamBasicDescription)commonRecorderAudioFormat {
  AudioStreamBasicDescription format;
  format.mSampleRate = kPreferredSampleRate;
  format.mFormatID = kAudioFormatLinearPCM;
  format.mFormatFlags =
      kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
  format.mBytesPerPacket = kBytesPerSample;
  format.mFramesPerPacket = 1;  // uncompressed.
  format.mBytesPerFrame = kBytesPerSample;
  format.mChannelsPerFrame = kRTCAudioSessionPreferredNumberOfChannels;
  format.mBitsPerChannel = 8 * kBytesPerSample;
  return format;
}

+ (BOOL)setupAudioSessionForRecordAndPlay {
  return [self setupAudioSessionForCategory:AVAudioSessionCategoryPlayAndRecord];
}

+ (BOOL)setupAudioSessionForCategory:(AVAudioSessionCategory)category {
  NSError *error = nullptr;
  [[AVAudioSession sharedInstance] setCategory:category error:&error];
  if (error) {
    NSLog(@"======setCategory error:%@", error);
    return NO;
  }
  [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:kPreferredIOBufferDuration error:&error];
  if (error) {
    NSLog(@"======setPreferredIOBufferDuration error:%@", error);
    return NO;
  }
  
  NSLog(@"======acutally io buffer duration: %@", @([AVAudioSession sharedInstance].IOBufferDuration));
  
  [[AVAudioSession sharedInstance] setPreferredSampleRate:kPreferredSampleRate error:&error];
  if (error) {
    NSLog(@"======DEBUG %s %@ %@", __FUNCTION__, @"setPreferredSampleRate error", [error localizedDescription]);
    return NO;
  }

  // activate the audio session
  [[AVAudioSession sharedInstance] setActive:YES error:&error];
  if (error) {
    NSLog(@"======DEBUG %s %@ %@", __FUNCTION__, @"setActive error", [error localizedDescription]);
    return NO;
  }
  
  return YES;
}


@end
