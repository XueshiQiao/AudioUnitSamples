//
//  SampleListViewController.m
//  AudioUnitSamples
//
//  Created by joey on 2022/1/25.
//

#import "SampleListViewController.h"
#import "BasicRecordAndPlaySampleViewController.h"

@interface SampleListViewController ()

@end

@implementation SampleListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)didTapbasicRecordAndPlay:(id)sender {
  [self.navigationController pushViewController:[BasicRecordAndPlaySampleViewController new] animated:YES];
}

@end
