//
//  AUGraphRecorderPlayer.h
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/28.
//

#import <AVFoundation/AVFoundation.h>
#import <memory>
#import "AudioFileReader.h"
#import "AudioFileWriter.h"

namespace samples {

class AUGraphRecorderPlayer {
  
public:
  AUGraphRecorderPlayer(AudioStreamBasicDescription format,
                        CFURLRef music_file_url,
                        CFURLRef export_file_url);
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
  
  static OSStatus OnAskForMusicAudioBufferRenderCallback(void *inRefCon,
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
  AudioBufferList vocal_buffer_;
  AudioBufferList mixed_buffer_for_pushing_;
  
  std::unique_ptr<AudioFileReader> music_file_reader_;
  std::unique_ptr<AudioFileWriter> export_file_writer_;
  
  AUGraph graph_{nullptr};
  
  AUNode io_node_;
  AudioUnit io_unit_;
  
  AUNode mixer_node_;
  AudioUnit mixer_unit_;
  
  AUNode music_player_node_;
  AudioUnit music_player_unit_;
};

}  // namespace samples
