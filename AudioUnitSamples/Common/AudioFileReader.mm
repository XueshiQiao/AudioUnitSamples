//
//  AudioFileReader.m
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/26.
//

#import "AudioFileReader.h"
#import "CommonUtils.h"

namespace samples {

AudioFileReader::AudioFileReader(CFURLRef file_path,
                                 AudioStreamBasicDescription format)
    : file_path_(file_path), format_(format) {}

void AudioFileReader::OpenFile() {
  CheckHasError(AudioFileOpenURL(file_path_, kAudioFileReadPermission,
                                 kAudioFileWAVEType, &file_id_),
                "open wav file");
}

void AudioFileReader::CloseFile() {
  CheckHasError(AudioFileClose(file_id_), "close wav file");
}

void AudioFileReader::ReadAudioFrame(size_t size, void *data, bool& eof) {
  UInt32 read_size = static_cast<UInt32>(size);
  OSStatus status = CheckErrorStatus(AudioFileReadBytes(file_id_,
                                                        false,
                                                        read_offset_,
                                                        &read_size,
                                                        data),
                                 "read audio frame from file");
  if (status == noErr) {
    read_offset_ += size;
  }
  
  if ((status == kAudioFileEndOfFileError) || (read_size < size)) {
    // eof, 返回静音数据
    memset(data, 0, size);
    eof = true;
  }
}

}  // namespace samples
