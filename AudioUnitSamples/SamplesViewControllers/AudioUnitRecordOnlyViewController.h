//
//  AudioUnitRecordOnlyViewController.h
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN


/// 使用 AudioUnit 进行录制, 录制完成之后保存到文件中
/// 使用 InputCallback 驱动, 调用 AudioUnitRender 获取到采集到的音频数据,
/// 然后把这些数据保存到文件中
@interface AudioUnitRecordOnlyViewController : UIViewController

@end

NS_ASSUME_NONNULL_END
