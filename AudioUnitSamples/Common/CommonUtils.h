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
  std::cout << "======error occurred @ " << operation << ", error code: " << status << std::endl;
  return true;
}

inline OSStatus CheckErrorStatus(OSStatus status, const std::string& operation) {
  if (status != noErr) {
    std::cout << "======error occurred @ " << operation << ", error code: " << status << std::endl;
  }
  return status;
}


@interface CommonUtils : NSObject

+ (AudioStreamBasicDescription)commonRecorderAudioFormat;

+ (BOOL)setupAudioSessionForRecordAndPlay;

+ (BOOL)setupAudioSessionForCategory:(AVAudioSessionCategory)category;

@end

static void MixSInt16AudioSamples(SInt16 *dst, SInt16 *src,
                                  float dst_factor, float src_factor,
                                  size_t size_in_bytes) {
  for (size_t i = 0; i < size_in_bytes / sizeof(SInt16); i++) {
    *(dst + i) = static_cast<SInt16>(*(dst + i) * dst_factor) +
                 static_cast<SInt16>(*(src + i) * src_factor);
  }
}

static bool MixAudioBufferList(AudioBufferList& dst, const AudioBufferList& src,
                               float dst_factor, float src_factor) {
  if (dst.mNumberBuffers != src.mNumberBuffers ||
      (dst.mBuffers[0].mDataByteSize != src.mBuffers[0].mDataByteSize)) {
    return false;
  }
  SInt16 *_dst = static_cast<SInt16*>(dst.mBuffers[0].mData);
  SInt16 *_src = static_cast<SInt16*>(src.mBuffers[0].mData);
  MixSInt16AudioSamples(_dst, _src, dst_factor, src_factor, src.mBuffers[0].mDataByteSize);
  return true;
}

static void InitAudioBufferList(AudioBufferList* audio_buffer) {
  UInt32 sizeInBytes = 512;
  audio_buffer->mNumberBuffers = 1;
  audio_buffer->mBuffers[0].mNumberChannels = [CommonUtils commonRecorderAudioFormat].mChannelsPerFrame;
  audio_buffer->mBuffers[0].mDataByteSize = sizeInBytes;
  audio_buffer->mBuffers[0].mData = malloc(sizeInBytes);
  memset(audio_buffer->mBuffers[0].mData, 0, sizeInBytes);
}

static void DisposeAudioBufferList(AudioBufferList* audio_buffer) {
  for (size_t i = 0; i < audio_buffer->mNumberBuffers; i++) {
    if (audio_buffer->mBuffers[0].mData) {
      free(audio_buffer->mBuffers[0].mData);
    }
  }
}

static bool CopyAudioBufferListDatas(AudioBufferList& dst, const AudioBufferList& src) {
  if (dst.mNumberBuffers != src.mNumberBuffers) {
    return false;
  }
  
  for (size_t i = 0; i < dst.mNumberBuffers; i++) {
    if (dst.mBuffers[i].mDataByteSize >= src.mBuffers[0].mDataByteSize) {
      memcpy(dst.mBuffers[i].mData, src.mBuffers[0].mData, src.mBuffers[0].mDataByteSize);
    } else {
      return false;
    }
  }

  return true;
}


NS_ASSUME_NONNULL_END
