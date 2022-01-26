//
//  AudioFileReader.h
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/26.
//

#import <AVFoundation/AVFoundation.h>

namespace samples {

class AudioFileReader {
  
public:
  AudioFileReader(CFURLRef file_path, AudioStreamBasicDescription format);
  
  void OpenFile();
  
  void CloseFile();
  
  void ReadAudioFrame(size_t size, void *data, bool& eof);
  
private:
  AudioFileID file_id_;
  CFURLRef file_path_;
  
  SInt64 read_offset_{0};
  
  AudioStreamBasicDescription format_;
  
};

}  // namespace smaples
