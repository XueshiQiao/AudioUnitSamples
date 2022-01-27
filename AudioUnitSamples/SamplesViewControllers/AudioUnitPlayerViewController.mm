//
//  AudioUnitPlayerViewController.m
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/26.
//

#import "AudioUnitPlayerViewController.h"
#import "AudioFileReader.h"
#import "AudioUnitPlayer.h"
#import "CommonUtils.h"
#include <memory>

@interface AudioUnitPlayerViewController () {
  std::unique_ptr<samples::AudioFileReader> file_reader_;
  std::unique_ptr<samples::AudioFileReader> file_reader_english_;

  std::unique_ptr<samples::AudioUnitPlayer> audio_unit_player_;
  AudioBufferList buffer_list_;
}

@property (nonatomic, strong) NSURL *audioFileURL;
@property (nonatomic, strong) NSURL *audioEnglishFileURL;

@end

@implementation AudioUnitPlayerViewController

- (void)dealloc {
  free(buffer_list_.mBuffers[0].mData);
}

- (void)viewDidLoad {
  [super viewDidLoad];
  NSURL *documentFolderPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
  self.audioFileURL = [documentFolderPath URLByAppendingPathComponent:@"recorded_audio_num.wav"];
  NSLog(@"======read file path: %@", self.audioFileURL.absoluteString);
  
  self.audioEnglishFileURL = [documentFolderPath URLByAppendingPathComponent:@"recorded_audio_num_english.wav"];
  
  [CommonUtils setupAudioSessionForCategory:AVAudioSessionCategoryPlayAndRecord];
  
  buffer_list_.mNumberBuffers = 1;
  buffer_list_.mBuffers[0].mNumberChannels = [CommonUtils commonRecorderAudioFormat].mChannelsPerFrame;
  buffer_list_.mBuffers[0].mDataByteSize = 512;
  buffer_list_.mBuffers[0].mData = malloc(buffer_list_.mBuffers[0].mDataByteSize);
  
//  CFURLRef url = (__bridge  CFURLRef)self.filePath;
//  AudioStreamBasicDescription format = [CommonUtils commonRecorderAudioFormat];
//  wrapper_ = std::make_unique<samples::AudioUnitRecorder>(format, url);
//  wrapper_->SetUpAudioUnit();
//  
//  file_writer_ = std::make_unique<samples::AudioFileWriter>(url, format);
//  file_writer_->CreateFile();
//
//  wrapper_->SetOnRecordAudioBufferCallback([=](const AudioBufferList& audio_buffer) {
//    file_writer_->WriteAudioPacket(audio_buffer.mBuffers[0].mData, audio_buffer.mBuffers[0].mDataByteSize);
//  });
//  wrapper_->StartAudioUnit();

}

- (IBAction)didTapStartPlayingButton:(id)sender {
  file_reader_ = std::make_unique<samples::AudioFileReader>(
      (__bridge CFURLRef)self.audioFileURL,
      [CommonUtils commonRecorderAudioFormat]);
  file_reader_->OpenFile();
  
  file_reader_english_ = std::make_unique<samples::AudioFileReader>(
      (__bridge CFURLRef)self.audioEnglishFileURL,
      [CommonUtils commonRecorderAudioFormat]);
  file_reader_english_->OpenFile();
  
  audio_unit_player_ = std::make_unique<samples::AudioUnitPlayer>([CommonUtils commonRecorderAudioFormat]);
  audio_unit_player_->SetOnRecordAudioBufferCallback([=](void* data, size_t size, bool& eof) {
    self->file_reader_->ReadAudioFrame(size, data, eof);
    self->file_reader_english_->ReadAudioFrame(size, buffer_list_.mBuffers[0].mData, eof);
    SInt16 *data1 = static_cast<SInt16 *>(data);
    SInt16 *data2 = static_cast<SInt16 *>(buffer_list_.mBuffers[0].mData);
    MixSInt16AudioSamples(data1, data2, 0.5, 0.5, size);
  });
  
  audio_unit_player_->SetUpAudioUnit();
  audio_unit_player_->StartAudioUnit();
}

- (IBAction)didTapStopPlayingButton:(id)sender {
  file_reader_->CloseFile();
  file_reader_english_->CloseFile();
  audio_unit_player_->StopAudioUnit();
}

- (IBAction)didTapMuteButton:(id)sender {
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
