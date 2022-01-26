//
//  AudioUnitRecorderAndPlayer.h
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/27.
//

#import <AVFoundation/AVFoundation.h>

namespace samples {
 
class AudioUnitRecorderAndPlayer {
public:
  AudioUnitRecorderAndPlayer(const AudioStreamBasicDescription& format);
  
  bool SetUpAudioUnit();
  
  bool StartAudioUnit();
  
  void StopAudioUnit();
  
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

};

}
