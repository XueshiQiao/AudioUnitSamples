//
//  AudioUnitRecorderAndPlayerComplex.h
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/27.
//

#import <AVFoundation/AVFoundation.h>
#include <functional>
#include <memory>

namespace samples {
 
class AudioUnitRecorderAndPlayerComplex {
public:
  using OnAskForAudioBufferCallback =
    std::function<void(AudioBufferList& audio_buffer)>;
  
  using OnRecordAudioBufferCallback =
    std::function<void(const AudioBufferList& recorded_audio_buffer)>;

  AudioUnitRecorderAndPlayerComplex(const AudioStreamBasicDescription& format);
  
  bool SetUpAudioUnit();
  
  bool StartAudioUnit();
  
  void StopAudioUnit();
  
  void SetOnAskForAudioBufferCallback(OnAskForAudioBufferCallback callback) {
    ask_for_audio_buffer_callback_ = callback;
  }
  
  void SetOnRecordAudioBufferCallback(OnRecordAudioBufferCallback callback) {
    recorded_audio_buffer_callback_ = callback;
  }
  
private:
  static OSStatus OnIOUnitRenderNotify(void * inRefCon,
                                       AudioUnitRenderActionFlags *ioActionFlags,
                                       const AudioTimeStamp *inTimeStamp,
                                       UInt32 inBusNumber,
                                       UInt32 inNumberFrames,
                                       AudioBufferList * ioData);
  static OSStatus OnAskingForMoreDataForPlayingRenderCallback(void * inRefCon,
                                                              AudioUnitRenderActionFlags *ioActionFlags,
                                                              const AudioTimeStamp *inTimeStamp,
                                                              UInt32 inBusNumber,
                                                              UInt32 inNumberFrames,
                                                              AudioBufferList * ioData);
  
  static OSStatus OnRecordedDataIsAvailable(void * inRefCon,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp *inTimeStamp,
                                          UInt32 inBusNumber,
                                          UInt32 inNumberFrames,
                                          AudioBufferList * ioData);

  
  
  AudioStreamBasicDescription format_;
  AudioUnit io_unit_;
  AudioBufferList buffer_;
  
  OnAskForAudioBufferCallback ask_for_audio_buffer_callback_;
  OnRecordAudioBufferCallback recorded_audio_buffer_callback_;
};

}
