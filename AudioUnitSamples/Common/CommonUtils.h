//
//  CommonUtils.h
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/26.
//

#import <AVFoundation/AVFoundation.h>
#include <string>
#include <iostream>

NS_ASSUME_NONNULL_BEGIN


// A VP I/O unit's bus 1 connects to input hardware (microphone).
static const AudioUnitElement kInputBus = 1;
// A VP I/O unit's bus 0 connects to output hardware (speaker).
static const AudioUnitElement kOutputBus = 0;

static const int kRTCAudioSessionPreferredNumberOfChannels = 1;
static const int kBytesPerSample = 2;

static const int kPreferredSampleRate = 48000;
static const NSTimeInterval kPreferredIOBufferDuration = 0.005;  // 5 ms

/// return true if found error
inline bool CheckHasError(OSStatus status, const std::string& operation) {
  if (status == noErr) {
    return false;
  }
  std::cout << "error occurred @ " << operation << ", error code: " << status << std::endl;
  return true;
}

inline OSStatus CheckErrorStatus(OSStatus status, const std::string& operation) {
  if (status != noErr) {
    std::cout << "error occurred @ " << operation << ", error code: " << status << std::endl;
  }
  return status;
}


@interface CommonUtils : NSObject

+ (AudioStreamBasicDescription)commonRecorderAudioFormat;

+ (BOOL)setupAudioSessionForRecordAndPlay;

+ (BOOL)setupAudioSessionForCategory:(AVAudioSessionCategory)category;

@end

NS_ASSUME_NONNULL_END
