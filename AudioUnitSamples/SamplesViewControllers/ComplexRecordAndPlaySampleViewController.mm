//
//  ComplexRecordAndPlaySampleViewController.m
//  AudioUnitSamples
//
//  Created by joey on 2022/1/25.
//

#import "ComplexRecordAndPlaySampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolBox/AudioToolBox.h>
#import <AVFAudio/AVFAudio.h>
#import "CommonUtils.h"
#import "AudioUnitRecorderAndPlayerComplex.h"
#import "AudioFileReader.h"
#import "AudioFileWriter.h"
#include <memory>

@interface ComplexRecordAndPlaySampleViewController () {
  std::unique_ptr<samples::AudioUnitRecorderAndPlayerComplex> audio_unit_rec_player_;
  std::unique_ptr<samples::AudioFileReader> file_reader_;
  std::unique_ptr<samples::AudioFileWriter> file_writer_;

  AudioBufferList vocal_audio_buffer_;  // recorded pure vocal buffer
  AudioBufferList music_audio_buffer_;  // music buffer read from local file
  
  AudioBufferList iounit_output_mixed_audio_buffer_;   // music buffer + vocal buffer (if ear monitor is enabled)
  AudioBufferList export_mixed_audio_buffer_;  // music + vocal
}
@property (nonatomic, strong) NSURL *musicFileURL;
@property (nonatomic, strong) NSURL *exportFileURL;
@property (nonatomic, assign) BOOL monitorEnabled;

@end

@implementation ComplexRecordAndPlaySampleViewController

- (void)dealloc {
  DisposeAudioBufferList(&vocal_audio_buffer_);
  DisposeAudioBufferList(&music_audio_buffer_);
  DisposeAudioBufferList(&iounit_output_mixed_audio_buffer_);
  DisposeAudioBufferList(&export_mixed_audio_buffer_);
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    InitAudioBufferList(&vocal_audio_buffer_);
    InitAudioBufferList(&music_audio_buffer_);
    InitAudioBufferList(&iounit_output_mixed_audio_buffer_);
    InitAudioBufferList(&export_mixed_audio_buffer_);
    _monitorEnabled = YES;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  NSURL *documentFolderPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
  self.musicFileURL = [documentFolderPath URLByAppendingPathComponent:@"recorded_audio_num.wav"];
  NSLog(@"======read file path: %@", self.musicFileURL.absoluteString);
  
  self.exportFileURL = [documentFolderPath URLByAppendingPathComponent:@"recorded_export.wav"];
}

- (IBAction)didTapStartRecordButton:(id)sender {
  [CommonUtils setupAudioSessionForRecordAndPlay];
  
  file_reader_ = std::make_unique<samples::AudioFileReader>(
      (__bridge CFURLRef)self.musicFileURL,
      [CommonUtils commonRecorderAudioFormat]);
  file_reader_->OpenFile();
  
  file_writer_ = std::make_unique<samples::AudioFileWriter>((__bridge CFURLRef)self.exportFileURL,
                                                            [CommonUtils commonRecorderAudioFormat]);
  file_writer_->CreateFile();
  
  audio_unit_rec_player_ = std::make_unique<samples::AudioUnitRecorderAndPlayerComplex>([CommonUtils commonRecorderAudioFormat]);
  audio_unit_rec_player_->SetOnRecordAudioBufferCallback([=](const AudioBufferList& audio_buffer) {
    CopyAudioBufferListDatas(vocal_audio_buffer_, audio_buffer);
    bool eof = false;
    file_reader_->ReadAudioFrame(music_audio_buffer_.mBuffers[0].mDataByteSize,
                                 music_audio_buffer_.mBuffers[0].mData,
                                 eof);
    CopyAudioBufferListDatas(iounit_output_mixed_audio_buffer_, music_audio_buffer_);
    if (self.monitorEnabled) {
      MixAudioBufferList(iounit_output_mixed_audio_buffer_, vocal_audio_buffer_, 0.5, 0.5);
    }
  });
  
  audio_unit_rec_player_->SetOnAskForAudioBufferCallback([=](AudioBufferList& audio_buffer) {
    CopyAudioBufferListDatas(audio_buffer, iounit_output_mixed_audio_buffer_);
    CopyAudioBufferListDatas(export_mixed_audio_buffer_, vocal_audio_buffer_);
    MixAudioBufferList(export_mixed_audio_buffer_, music_audio_buffer_, 0.5, 0.5);
    file_writer_->WriteAudioPacket(export_mixed_audio_buffer_.mBuffers[0].mData,
                                   export_mixed_audio_buffer_.mBuffers[0].mDataByteSize);
  });

  audio_unit_rec_player_->SetUpAudioUnit();
  audio_unit_rec_player_->StartAudioUnit();
}

- (IBAction)didTapStopRecordButton:(id)sender {
  audio_unit_rec_player_->StopAudioUnit();
  file_reader_->CloseFile();
  file_writer_->CloseFile();
}
- (IBAction)monitorStateChanged:(UISwitch *)sender {
  self.monitorEnabled = sender.isOn;
}

@end
