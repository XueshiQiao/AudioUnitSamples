//
//  AudioFileWriter.m
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/26.
//

#import "AudioFileWriter.h"

namespace samples {

AudioFileWriter::AudioFileWriter(CFURLRef file_ref,
                const AudioStreamBasicDescription& format)
  : file_ref_(file_ref), format_(format) {
}

void AudioFileWriter::CreateFile() {
  std::cout << "======create file @ " << CFURLGetString(file_ref_) << std::endl;
  AudioFileFlags flags = kAudioFileFlags_DontPageAlignAudioData | kAudioFileFlags_EraseFile;
  CheckHasError(AudioFileCreateWithURL(file_ref_, kAudioFileWAVEType, &format_, flags, &file_id_),
                "Create audio file id");
}

void AudioFileWriter::WriteAudioPacket(const void *buffer, UInt32 size) {
  if (!CheckHasError(AudioFileWriteBytes(file_id_, false, write_offset_, &size, buffer), "write bytes")) {
    write_offset_ += size;
  }
}

void AudioFileWriter::CloseFile() {
  std::cout << "======close file" << std::endl;
  CheckHasError(AudioFileClose(file_id_), "close file");
}

}  // namespace samples
