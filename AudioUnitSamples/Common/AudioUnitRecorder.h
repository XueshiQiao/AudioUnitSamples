//
//  AudioUnitRecorder.h
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
  
class AudioUnitRecorder {
public:
  using OnRecordAudioBufferCallback =
    std::function<void(const AudioBufferList& recorded_audio_buffer)>;
  
  AudioUnitRecorder(AudioStreamBasicDescription format, CFURLRef record_file_url);
  
  virtual ~AudioUnitRecorder() {
    free(audio_buffer_list_.mBuffers[0].mData);
  }
  
  bool SetUpAudioUnit();
  
  bool StartAudioUnit();
  
  void StopAudioUnit();

  void SetOnRecordAudioBufferCallback(OnRecordAudioBufferCallback callback) {
    std::cout << "set audio unit wrapper OnRecordAudioBufferCallback" << std::endl;
    on_record_callback_ = callback;
  }
  
  static OSStatus OnRecordedDataIsAvailable(void * inRefCon,
                                            AudioUnitRenderActionFlags *ioActionFlags,
                                            const AudioTimeStamp *inTimeStamp,
                                            UInt32 inBusNumber,
                                            UInt32 inNumberFrames,
                                            AudioBufferList *ioData);

protected:
  
  AudioUnit io_unit_;
  AudioFileID audio_file_;
  AudioBufferList audio_buffer_list_;
  AudioStreamBasicDescription audio_format_;
  
  OnRecordAudioBufferCallback on_record_callback_{nullptr};
};
  
}  // samples

