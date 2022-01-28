//
//  CommonUtils.m
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/26.
//

#import "CommonUtils.h"

void MixSInt16AudioSamples(SInt16 *dst, SInt16 *src,
                           float dst_factor, float src_factor,
                           size_t size_in_bytes) {
  for (size_t i = 0; i < size_in_bytes / sizeof(SInt16); i++) {
    *(dst + i) = static_cast<SInt16>(*(dst + i) * dst_factor) +
                 static_cast<SInt16>(*(src + i) * src_factor);
  }
}

bool MixAudioBufferList(AudioBufferList& dst, const AudioBufferList& src,
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

void InitAudioBufferList(AudioBufferList* audio_buffer) {
  UInt32 sizeInBytes = 512;
  audio_buffer->mNumberBuffers = 1;
  audio_buffer->mBuffers[0].mNumberChannels = [CommonUtils commonRecorderAudioFormat].mChannelsPerFrame;
  audio_buffer->mBuffers[0].mDataByteSize = sizeInBytes;
  audio_buffer->mBuffers[0].mData = malloc(sizeInBytes);
  memset(audio_buffer->mBuffers[0].mData, 0, sizeInBytes);
}

void DisposeAudioBufferList(AudioBufferList* audio_buffer) {
  for (size_t i = 0; i < audio_buffer->mNumberBuffers; i++) {
    if (audio_buffer->mBuffers[0].mData) {
      free(audio_buffer->mBuffers[0].mData);
    }
  }
}

bool CopyAudioBufferListDatas(AudioBufferList& dst, const AudioBufferList& src) {
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
