//
//  AppDelegate.m
//  AudioUnitSamples
//
//  Created by joey on 2022/1/25.
//

#import "AppDelegate.h"
#import "SampleListViewController.h"

@interface AppDelegate ()

//@property (nonatomic, strong) UIWindow window;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Override point for customization after application launch.
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  UINavigationController *rootVC = [[UINavigationController alloc] initWithRootViewController:[SampleListViewController new]];
  self.window.rootViewController = rootVC;
  [self.window makeKeyAndVisible];
  return YES;
}


@end
