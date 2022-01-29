//
//  SampleListViewController.m
//  AudioUnitSamples
//
//  Created by joey on 2022/1/25.
//

#import "SampleListViewController.h"
#import "BasicRecordAndPlaySampleViewController.h"

static NSString const * const kSampleListTableViewCellID = @"SampleListTableViewCell";

@interface SampleListViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *samplesTableView;
@property (strong, nonatomic) NSArray<Class>* clazzes;

@end

@implementation SampleListViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.clazzes = @[
    NSClassFromString(@"AudioUnitPlayerViewController"),
    NSClassFromString(@"AudioUnitRecordOnlyViewController"),
    NSClassFromString(@"BasicRecordAndPlaySampleViewController"),
    NSClassFromString(@"ComplexRecordAndPlaySampleViewController"),
    NSClassFromString(@"AUGraphRecordAndPlaySampleViewController"),
  ];
  [self.samplesTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:(NSString *)kSampleListTableViewCellID];
  self.samplesTableView.delegate = self;
  self.samplesTableView.dataSource = self;
  [self.samplesTableView reloadData];
}

- (IBAction)didTapbasicRecordAndPlay:(id)sender {
  [self.navigationController pushViewController:[BasicRecordAndPlaySampleViewController new] animated:YES];

}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return self.clazzes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:(NSString *)kSampleListTableViewCellID];
  cell.textLabel.text = NSStringFromClass(self.clazzes[indexPath.row]);
  cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  UIViewController *sampleViewController = [self.clazzes[indexPath.row] new];
  [self.navigationController pushViewController:sampleViewController animated:YES];
}

@end
