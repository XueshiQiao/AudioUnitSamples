//
//  AudioUnitRecordOnlyViewController.m
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/26.
//

#import "AudioUnitRecordOnlyViewController.h"
#import <AVFoundation/AVFoundation.h>
#include <string>
#include <memory>
#include <functional>
#import "CommonUtils.h"
#import "AudioFileWriter.h"
#import "AudioUnitRecorder.h"

#pragma mark - AudioUnitRecordOnlyViewController
@interface AudioUnitRecordOnlyViewController () {
  std::unique_ptr<samples::AudioUnitRecorder> wrapper_;
  std::unique_ptr<samples::AudioFileWriter> file_writer_;
}

@property (nonatomic, strong) NSURL *filePath;

@end

@implementation AudioUnitRecordOnlyViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  NSURL *documentFolderPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
  self.filePath = [documentFolderPath URLByAppendingPathComponent:@"recorded_audio.wav"];
  NSLog(@"======file path: %@", self.filePath.absoluteString);
  
  [CommonUtils setupAudioSessionForRecordAndPlay];
}

- (IBAction)didTapRecordButton:(id)sender {
  CFURLRef url = (__bridge  CFURLRef)self.filePath;
  AudioStreamBasicDescription format = [CommonUtils commonRecorderAudioFormat];
  wrapper_ = std::make_unique<samples::AudioUnitRecorder>(format, url);
  wrapper_->SetUpAudioUnit();
  
  file_writer_ = std::make_unique<samples::AudioFileWriter>(url, format);
  file_writer_->CreateFile();

  wrapper_->SetOnRecordAudioBufferCallback([=](const AudioBufferList& audio_buffer) {
    file_writer_->WriteAudioPacket(audio_buffer.mBuffers[0].mData, audio_buffer.mBuffers[0].mDataByteSize);
  });
  wrapper_->StartAudioUnit();
}

- (IBAction)didTapStopRecordingButton:(id)sender {
  wrapper_->StopAudioUnit();
  file_writer_->CloseFile();
}

@end


