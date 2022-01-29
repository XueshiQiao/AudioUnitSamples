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
  
  static OSStatus OnAskForExportMixedAudioBufferRenderCallback(void *inRefCon,
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
  
  static OSStatus OnAskForExportVocalAudioBufferRenderCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData);
  
  static OSStatus OnAskForExportMusicAudioBufferRenderCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData);

  AudioStreamBasicDescription format_;
  AudioBufferList vocal_buffer_;
  AudioBufferList music_buffer_;
  
  std::unique_ptr<AudioFileReader> music_file_reader_;
  std::unique_ptr<AudioFileWriter> export_file_writer_;
  
  dispatch_queue_t writer_serial_queue_;
  
  AUGraph graph_{nullptr};
  
  AUNode io_node_;
  AudioUnit io_unit_;
  
  AUNode mixer_node_;
  AudioUnit mixer_unit_;
  
  AUNode music_player_node_;
  AudioUnit music_player_unit_;
  
  AUNode export_mixer_node_;
  AudioUnit export_mixer_unit_;
};

}  // namespace samples
