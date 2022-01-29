//
//  AUGraphRecorderPlayer.h
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/28.
//

#import <AVFoundation/AVFoundation.h>

namespace samples {

class AUGraphRecorderPlayer {
  
public:
  AUGraphRecorderPlayer(AudioStreamBasicDescription format);
  virtual ~AUGraphRecorderPlayer();
  
  void InitializeGraph();
  
  void Start();
  
  void Stop();
  
  bool IsRunning();
  
private:
  
  static OSStatus OnAskForVocalAudioBufferRenderCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData);
                                 
  static OSStatus OnIOUnitAudioBufferIsAvailable(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData);
  
  static OSStatus OnIOUnitRenderNotify(void * inRefCon,
                                       AudioUnitRenderActionFlags *ioActionFlags,
                                       const AudioTimeStamp *inTimeStamp,
                                       UInt32 inBusNumber,
                                       UInt32 inNumberFrames,
                                       AudioBufferList * ioData);


  AudioStreamBasicDescription format_;
  AudioBufferList buffer_;
  
  AUGraph graph_;
  
  AUNode io_node_;
  AudioUnit io_unit_;
  
  AUNode mixer_node_;
  AudioUnit mixer_unit_;
  
  AUNode music_player_node_;
  AudioUnit music_player_unit_;
};

}  // namespace samples
