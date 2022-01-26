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

// A VP I/O unit's bus 1 connects to input hardware (microphone).
static const AudioUnitElement kInputBus = 1;
// A VP I/O unit's bus 0 connects to output hardware (speaker).
static const AudioUnitElement kOutputBus = 0;
static const int kRTCAudioSessionPreferredNumberOfChannels = 1;
static const int kBytesPerSample = 2;

@interface BasicRecordAndPlaySampleViewController () {
  AudioUnit _ioUnit;
}

@end

@implementation BasicRecordAndPlaySampleViewController

- (void)viewDidLoad {
  [super viewDidLoad];
}

- (IBAction)didTapStartRecordButton:(id)sender {
  // audio session
  NSError *error = nullptr;
  [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
  if (error) {
      NSLog(@"setCategory error:%@", error);
  }
  [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.005 error:&error];
  if (error) {
      NSLog(@"setPreferredIOBufferDuration error:%@", error);
  }
  
  [[AVAudioSession sharedInstance] setPreferredSampleRate:48000 error:&error];
  if (error) {
      NSLog(@"DEBUG %s %@ %@", __FUNCTION__, @"setPreferredSampleRate error", [error localizedDescription]);
  }

  // activate the audio session
  [[AVAudioSession sharedInstance] setActive:YES error:&error];
  if (error) {
      NSLog(@"DEBUG %s %@ %@", __FUNCTION__, @"setActive error", [error localizedDescription]);
  }
  
  if (![self createIOUnit]) {
    NSLog(@"create io unit failed");
  }
  if (![self configAudioUnit]) {
    NSLog(@"config audio unit failed");
  }
  if (![self startAudioUnit]) {
    NSLog(@"start audio unit failed");
  }
}

- (IBAction)didTapStopRecordButton:(id)sender {
}

static OSStatus ioUnitRenderNotify(void *              inRefCon,
                                      AudioUnitRenderActionFlags *  ioActionFlags,
                                      const AudioTimeStamp *      inTimeStamp,
                                      UInt32              inBusNumber,
                                      UInt32              inNumberFrames,
                                      AudioBufferList *        ioData)
{
//    // !!! this method is timing sensitive, better not add any wasting time code here, even nslog
//    if (*ioActionFlags & kAudioUnitRenderAction_PostRender) {
//    }
  NSLog(@"====== %@", @(*ioActionFlags));
    return noErr;
}

- (AudioStreamBasicDescription)getFormat {
  // Set the application formats for input and output:
  // - use same format in both directions
  // - avoid resampling in the I/O unit by using the hardware sample rate
  // - linear PCM => noncompressed audio data format with one frame per packet
  // - no need to specify interleaving since only mono is supported
  AudioStreamBasicDescription format;
  format.mSampleRate = 48000;
  format.mFormatID = kAudioFormatLinearPCM;
  format.mFormatFlags =
      kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
  format.mBytesPerPacket = kBytesPerSample;
  format.mFramesPerPacket = 1;  // uncompressed.
  format.mBytesPerFrame = kBytesPerSample;
  format.mChannelsPerFrame = kRTCAudioSessionPreferredNumberOfChannels;
  format.mBitsPerChannel = 8 * kBytesPerSample;
  return format;
}

- (bool)createIOUnit {
  // Create an audio component description to identify the Voice Processing
  // I/O audio unit.
  AudioComponentDescription vpio_unit_description;
  vpio_unit_description.componentType = kAudioUnitType_Output;
  vpio_unit_description.componentSubType = kAudioUnitSubType_RemoteIO;
  vpio_unit_description.componentManufacturer = kAudioUnitManufacturer_Apple;
  vpio_unit_description.componentFlags = 0;
  vpio_unit_description.componentFlagsMask = 0;

  // Obtain an audio unit instance given the description.
  AudioComponent found_vpio_unit_ref =
      AudioComponentFindNext(nullptr, &vpio_unit_description);

  // Create a Voice Processing IO audio unit.
  OSStatus result = noErr;
  result = AudioComponentInstanceNew(found_vpio_unit_ref, &_ioUnit);
  if (result != noErr) {
    _ioUnit = nullptr;
    return false;
  }

  // Enable input on the input scope of the input element.
  UInt32 enable_input = 1;
  result = AudioUnitSetProperty(_ioUnit, kAudioOutputUnitProperty_EnableIO,
                                kAudioUnitScope_Input, kInputBus, &enable_input,
                                sizeof(enable_input));
  if (result != noErr) {
//    DisposeAudioUnit();
//    RTCLogError(@"Failed to enable input on input scope of input element. "
//                 "Error=%ld.",
//                (long)result);
    return false;
  }

  // Enable output on the output scope of the output element.
  UInt32 enable_output = 1;
  result = AudioUnitSetProperty(_ioUnit, kAudioOutputUnitProperty_EnableIO,
                                kAudioUnitScope_Output, kOutputBus,
                                &enable_output, sizeof(enable_output));
  if (result != noErr) {
//    DisposeAudioUnit();
//    RTCLogError(@"Failed to enable output on output scope of output element. "
//                 "Error=%ld.",
//                (long)result);
    return false;
  }

//  // Specify the callback function that provides audio samples to the audio
//  // unit.
//  AURenderCallbackStruct render_callback;
//  render_callback.inputProc = OnGetPlayoutData;
//  render_callback.inputProcRefCon = this;
//  result = AudioUnitSetProperty(
//      _ioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input,
//      kOutputBus, &render_callback, sizeof(render_callback));
//  if (result != noErr) {
////    DisposeAudioUnit();
////    RTCLogError(@"Failed to specify the render callback on the output bus. "
////                 "Error=%ld.",
////                (long)result);
//    return false;
//  }

  // Disable AU buffer allocation for the recorder, we allocate our own.
  // TODO(henrika): not sure that it actually saves resource to make this call.
  UInt32 flag = 0;
  result = AudioUnitSetProperty(
      _ioUnit, kAudioUnitProperty_ShouldAllocateBuffer,
      kAudioUnitScope_Output, kInputBus, &flag, sizeof(flag));
  if (result != noErr) {
//    DisposeAudioUnit();
//    RTCLogError(@"Failed to disable buffer allocation on the input bus. "
//                 "Error=%ld.",
//                (long)result);
    return false;
  }

  // Specify the callback to be called by the I/O thread to us when input audio
  // is available. The recorded samples can then be obtained by calling the
  // AudioUnitRender() method.
//  AURenderCallbackStruct input_callback;
//  input_callback.inputProc = OnDeliverRecordedData;
//  input_callback.inputProcRefCon = this;
//  result = AudioUnitSetProperty(vpio_unit_,
//                                kAudioOutputUnitProperty_SetInputCallback,
//                                kAudioUnitScope_Global, kInputBus,
//                                &input_callback, sizeof(input_callback));
  return true;
}

- (bool)configAudioUnit {
  OSStatus result = noErr;
  AudioStreamBasicDescription format = [self getFormat];
  UInt32 size = sizeof(format);

  // Set the format on the output scope of the input element/bus.
  result =
      AudioUnitSetProperty(_ioUnit, kAudioUnitProperty_StreamFormat,
                           kAudioUnitScope_Output, kInputBus, &format, size);
  if (result != noErr) {
//    RTCLogError(@"Failed to set format on output scope of input bus. "
//                 "Error=%ld.",
//                (long)result);
    return false;
  }

  // Set the format on the input scope of the output element/bus.
  result =
      AudioUnitSetProperty(_ioUnit, kAudioUnitProperty_StreamFormat,
                           kAudioUnitScope_Input, kOutputBus, &format, size);
  if (result != noErr) {
//    RTCLogError(@"Failed to set format on input scope of output bus. "
//                 "Error=%ld.",
//                (long)result);
    return false;
  }
  
  result = AudioUnitAddRenderNotify(_ioUnit, ioUnitRenderNotify, (__bridge  void *)self);

  // Initialize the Voice Processing I/O unit instance.
  // Calls to AudioUnitInitialize() can fail if called back-to-back on
  // different ADM instances. The error message in this case is -66635 which is
  // undocumented. Tests have shown that calling AudioUnitInitialize a second
  // time, after a short sleep, avoids this issue.
  // See webrtc:5166 for details.
//  int failed_initalize_attempts = 0;
  result = AudioUnitInitialize(_ioUnit);
  while (result != noErr) {
//    RTCLogError(@"Failed to initialize the Voice Processing I/O unit. "
//                 "Error=%ld.",
//                (long)result);
//    ++failed_initalize_attempts;
//    if (failed_initalize_attempts == kMaxNumberOfAudioUnitInitializeAttempts) {
//      // Max number of initialization attempts exceeded, hence abort.
//      RTCLogError(@"Too many initialization attempts.");
//      return false;
//    }
//    RTCLog(@"Pause 100ms and try audio unit initialization again...");
    [NSThread sleepForTimeInterval:0.1f];
    result = AudioUnitInitialize(_ioUnit);
  }
  if (result == noErr) {
//    RTCLog(@"Voice Processing I/O unit is now initialized.");
    return true;
  }
  return false;
}

- (bool)startAudioUnit {
  OSStatus result = AudioOutputUnitStart(_ioUnit);
  if (result != noErr) {
    return false;
  }
  return true;
}

@end
