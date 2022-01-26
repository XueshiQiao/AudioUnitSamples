//
//  AudioFileWriter.h
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/26.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#include <string>
#include <iostream>
#import "CommonUtils.h"

NS_ASSUME_NONNULL_BEGIN

namespace samples {

class AudioFileWriter {
public:
  AudioFileWriter(CFURLRef file_ref,
                  const AudioStreamBasicDescription& format);
  
  void CreateFile();
  
  void WriteAudioPacket(const void *buffer, UInt32 size);
  
  void CloseFile();
  
private:
  CFURLRef file_ref_;
  AudioStreamBasicDescription format_;
  
  AudioFileID file_id_;
  size_t write_offset_{0};
  
};

}  // namespace samples

NS_ASSUME_NONNULL_END
