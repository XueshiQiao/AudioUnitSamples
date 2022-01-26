//
//  AudioUnitPlayer.h
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/26.
//

#import <AVFoundation/AVFoundation.h>
#include <string>
#include <memory>
#include <functional>
#include <iostream>
#import "CommonUtils.h"

namespace samples {
  
class AudioUnitPlayer {
public:
  using OnAskForAudioBufferCallback =
    std::function<void(void* data, size_t size, bool& eof)>;
  
  AudioUnitPlayer(AudioStreamBasicDescription format);
  
  virtual ~AudioUnitPlayer() {
    free(audio_buffer_list_.mBuffers[0].mData);
  }
  
  bool SetUpAudioUnit();
  
  bool StartAudioUnit();
  
  void StopAudioUnit();

  void SetOnRecordAudioBufferCallback(OnAskForAudioBufferCallback callback) {
    std::cout << "======set audio unit wrapper OnRecordAudioBufferCallback" << std::endl;
    on_ask_audio_buffer_callback_ = callback;
  }
  
  static OSStatus OnAskingForMoreDataForPlayingRenderCallback(void * inRefCon,
                                            AudioUnitRenderActionFlags *ioActionFlags,
                                            const AudioTimeStamp *inTimeStamp,
                                            UInt32 inBusNumber,
                                            UInt32 inNumberFrames,
                                            AudioBufferList *ioData);
  
  static OSStatus ioUnitRenderNotify(void *              inRefCon,
                                        AudioUnitRenderActionFlags *  ioActionFlags,
                                        const AudioTimeStamp *      inTimeStamp,
                                        UInt32              inBusNumber,
                                        UInt32              inNumberFrames,
                                     AudioBufferList *        ioData);

protected:
  
  AudioUnit io_unit_;
  AudioBufferList audio_buffer_list_;
  AudioStreamBasicDescription audio_format_;
  
  OnAskForAudioBufferCallback on_ask_audio_buffer_callback_{nullptr};
};
  
}  // samples

