//
//  BasicRecordAndPlaySampleViewController.m
//  AudioUnitSamples
//
//  Created by joey on 2022/1/25.
//

#import "BasicRecordAndPlaySampleViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolBox/AudioToolBox.h>
#import <AVFAudio/AVFAudio.h>
#import "CommonUtils.h"
#import "AudioUnitRecorderAndPlayer.h"
#include <memory>

@interface BasicRecordAndPlaySampleViewController () {
  std::unique_ptr<samples::AudioUnitRecorderAndPlayer> audio_unit_rec_player_;
}

@end

@implementation BasicRecordAndPlaySampleViewController

- (void)viewDidLoad {
  [super viewDidLoad];
}

- (IBAction)didTapStartRecordButton:(id)sender {
  [CommonUtils setupAudioSessionForRecordAndPlay];
  
  audio_unit_rec_player_ = std::make_unique<samples::AudioUnitRecorderAndPlayer>([CommonUtils commonRecorderAudioFormat]);
  audio_unit_rec_player_->SetUpAudioUnit();
  audio_unit_rec_player_->StartAudioUnit();
}

- (IBAction)didTapStopRecordButton:(id)sender {
  audio_unit_rec_player_->StopAudioUnit();
}

@end
