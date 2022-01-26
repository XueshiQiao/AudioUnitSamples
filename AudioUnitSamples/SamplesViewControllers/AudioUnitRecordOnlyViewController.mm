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


#pragma mark - AudioUnitWrapper C++ Class

namespace {
  
class AudioUnitWrapper {
public:
  
  using OnRecordAudioBufferCallback =
    std::function<void(const AudioBufferList& recorded_audio_buffer)>;
  
  AudioUnitWrapper(AudioStreamBasicDescription format, CFURLRef record_file_url):
  audio_format_(format) {
    audio_buffer_list_.mNumberBuffers = 1;
    audio_buffer_list_.mBuffers[0].mNumberChannels = format.mChannelsPerFrame;
//    size_t bytes_per_frame = format.mChannelsPerFrame * format.mBytesPerFrame * format.mChannelsPerFrame;
//    size_t size = kPreferredSampleRate * kPreferredIOBufferDuration * bytes_per_frame;
    // TODO (xueshi) should be computed at runtime, not magic number
    audio_buffer_list_.mBuffers[0].mDataByteSize = 512; //size;
    audio_buffer_list_.mBuffers[0].mData = malloc(audio_buffer_list_.mBuffers[0].mDataByteSize);
  };
  
  ~AudioUnitWrapper() {
    free(audio_buffer_list_.mBuffers[0].mData);
  }
  
  bool SetUpAudioUnit() {
    std::cout << "setup audio unit" << std::endl;
    // Create an audio component description to identify the Voice Processing
    // I/O audio unit.
    AudioComponentDescription io_unit_description;
    io_unit_description.componentType = kAudioUnitType_Output;
    io_unit_description.componentSubType = kAudioUnitSubType_RemoteIO;
    io_unit_description.componentManufacturer = kAudioUnitManufacturer_Apple;
    io_unit_description.componentFlags = 0;
    io_unit_description.componentFlagsMask = 0;

    // Obtain an audio unit instance given the description.
    AudioComponent io_unit_ref =
        AudioComponentFindNext(nullptr, &io_unit_description);

    // Create a Voice Processing IO audio unit.
    if (CheckHasError(AudioComponentInstanceNew(io_unit_ref, &io_unit_), "create io unit")) {
      io_unit_ = nullptr;
      return false;
    }

    // Enable input on the input scope of the input element.
    UInt32 enable_input = 1;
    if (CheckHasError(AudioUnitSetProperty(io_unit_, kAudioOutputUnitProperty_EnableIO,
                                        kAudioUnitScope_Input, kInputBus, &enable_input,
                                        sizeof(enable_input)),
                   "set Property_EnableIO on inputbus : input scope")) {
      return false;
    }

    // Enable output on the output scope of the output element.
    UInt32 enable_output = 0;
    if (CheckHasError(AudioUnitSetProperty(io_unit_, kAudioOutputUnitProperty_EnableIO,
                                        kAudioUnitScope_Output, kOutputBus,
                                        &enable_output, sizeof(enable_output)),
                   "set Property_EnableIO on kOutputBus : output scope")) {
      return false;
    }

    // Disable AU buffer allocation for the recorder, we allocate our own.
    // TODO(henrika): not sure that it actually saves resource to make this call.
    UInt32 flag = 0;
    if (CheckHasError(AudioUnitSetProperty(
                                        io_unit_, kAudioUnitProperty_ShouldAllocateBuffer,
                                        kAudioUnitScope_Output, kInputBus, &flag, sizeof(flag)),
                   "set Property_ShouldAllocateBuffer on inputbus : output scope")) {
      return false;
    }

    AudioStreamBasicDescription format = audio_format_;
    UInt32 size = sizeof(format);
    // Set the format on the output scope of the input element/bus.
    if (CheckHasError(AudioUnitSetProperty(io_unit_, kAudioUnitProperty_StreamFormat,
                                        kAudioUnitScope_Output, kInputBus, &format, size),
                   "set Property_StreamFormat on inputbus : output scope")) {
      return false;
    }

    // Set the format on the input scope of the output element/bus.
    if (CheckHasError(AudioUnitSetProperty(io_unit_, kAudioUnitProperty_StreamFormat,
                                        kAudioUnitScope_Input, kOutputBus, &format, size),
                   "set Property_StreamFormat on outputbus : input scope")) {
      return false;
    }
    
//   Specify the callback to be called by the I/O thread to us when input audio
//   is available. The recorded samples can then be obtained by calling the
//   AudioUnitRender() method.
    
    // input callback 是告诉我们已经采集到了数据, 需要我们使用 AudioUnitRender 从上游获取采集到的数据
    // 注意回调到 OnRecordedDataIsAvailable 的参数里, ioData 是 nullptr, 所以在调用 AudioUnitRender
    // 时, 不可使用回调里的 ioData 参数, 需要我们自己创建
    AURenderCallbackStruct input_callback;
    input_callback.inputProc = OnRecordedDataIsAvailable;
    input_callback.inputProcRefCon = this;
    if (CheckHasError(AudioUnitSetProperty(io_unit_,
                                         kAudioOutputUnitProperty_SetInputCallback,
                                         kAudioUnitScope_Global, kInputBus,
                                        &input_callback, sizeof(input_callback)),
                   "set input callback on inputbus: global scope")) {
      return false;
    }

  // Initialize the Voice Processing I/O unit instance.
  // Calls to AudioUnitInitialize() can fail if called back-to-back on
  // different ADM instances. The error message in this case is -66635 which is
  // undocumented. Tests have shown that calling AudioUnitInitialize a second
  // time, after a short sleep, avoids this issue.
  // See webrtc:5166 for details.
  //  int failed_initalize_attempts = 0;
    bool has_error = CheckHasError(AudioUnitInitialize(io_unit_), "Initialize IO unit");
    while (has_error) {
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
      has_error = CheckHasError(AudioUnitInitialize(io_unit_), "Initialize IO unit");
    }

    return has_error;
  }
  
  bool StartAudioUnit() {
    std::cout << "start audio unit" << std::endl;
    return AudioOutputUnitStart(io_unit_);
  }
  
  void StopAudioUnit() {
    std::cout << "start audio unit" << std::endl;
    on_record_callback_ = nullptr;
    CheckHasError(AudioOutputUnitStop(io_unit_), "stop io unit");
    CheckHasError(AudioUnitUninitialize(io_unit_), "deinit io unit");
    CheckHasError(AudioComponentInstanceDispose(io_unit_), "dispose io unit");
  }
  
  
//  static OSStatus OnRecordedDataAvailable(void *              inRefCon,
//                                           AudioUnitRenderActionFlags *  ioActionFlags,
//                                           const AudioTimeStamp *      inTimeStamp,
//                                           UInt32              inBusNumber,
//                                           UInt32              inNumberFrames,
//                                           AudioBufferList *        ioData) {
//    BasicRecordAndPlaySampleViewController *vc = (__bridge BasicRecordAndPlaySampleViewController *)inRefCon;
//    OSStatus status = AudioUnitRender(vc->_ioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &vc->_buffer);
//    if (status != noErr) {
//      NSLog(@"AudioUnitRender error: %@", @(status));
//    }
//    return status;
//
//  }
  
  void SetOnRecordAudioBufferCallback(OnRecordAudioBufferCallback callback) {
    std::cout << "set audio unit wrapper OnRecordAudioBufferCallback" << std::endl;
    on_record_callback_ = callback;
  }

  static OSStatus OnRecordedDataIsAvailable(void * inRefCon,
                                     AudioUnitRenderActionFlags *ioActionFlags,
                                     const AudioTimeStamp *inTimeStamp,
                                     UInt32 inBusNumber,
                                     UInt32 inNumberFrames,
                                     AudioBufferList *ioData) {
    AudioUnitWrapper *wrapper = static_cast<AudioUnitWrapper *>(inRefCon);
    OSStatus status = CheckErrorStatus(AudioUnitRender(wrapper->io_unit_, ioActionFlags, inTimeStamp,
                           inBusNumber, inNumberFrames, &wrapper->audio_buffer_list_),
                            "AudioUnitRender call");
    if (status == noErr && wrapper->on_record_callback_) {
      wrapper->on_record_callback_(wrapper->audio_buffer_list_);
    }
    return status;
  }
  
private:
  
  AudioUnit io_unit_;
  AudioFileID audio_file_;
  AudioBufferList audio_buffer_list_;
  AudioStreamBasicDescription audio_format_;
  
  OnRecordAudioBufferCallback on_record_callback_{nullptr};
};
  
} //

#pragma mark - AudioUnitRecordOnlyViewController
@interface AudioUnitRecordOnlyViewController () {
  std::unique_ptr<AudioUnitWrapper> wrapper_;
  std::unique_ptr<samples::AudioFileWriter> file_writer_;
}

@property (nonatomic, strong) NSURL *filePath;

@end

@implementation AudioUnitRecordOnlyViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
  NSURL *documentFolderPath = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
  self.filePath = [documentFolderPath URLByAppendingPathComponent:@"recorded_audio.wav"];
  NSLog(@"file path: %@", self.filePath.absoluteString);
  
  [CommonUtils setupAudioSessionForRecordAndPlay];
}

- (IBAction)didTapRecordButton:(id)sender {
  CFURLRef url = (__bridge  CFURLRef)self.filePath;
  AudioStreamBasicDescription format = [CommonUtils commonRecorderAudioFormat];
  wrapper_ = std::make_unique<AudioUnitWrapper>(format, url);
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


