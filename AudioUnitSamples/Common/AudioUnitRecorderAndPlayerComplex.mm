//
//  AudioUnitRecorderAndPlayerComplex.m
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/27.
//

#import "AudioUnitRecorderAndPlayerComplex.h"
#include <memory>
#import "CommonUtils.h"

namespace samples {
  
AudioUnitRecorderAndPlayerComplex::AudioUnitRecorderAndPlayerComplex(const AudioStreamBasicDescription& format) : format_(format) {
  buffer_.mNumberBuffers = 1;
  buffer_.mBuffers[0].mNumberChannels = 1;
  buffer_.mBuffers[0].mDataByteSize = 4096;
  buffer_.mBuffers[0].mData = malloc(buffer_.mBuffers[0].mDataByteSize);
}
  
  bool AudioUnitRecorderAndPlayerComplex::SetUpAudioUnit() {
    std::cout << "======setup audio unit" << std::endl;
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
    if (CheckHasError(AudioComponentInstanceNew(io_unit_ref, &io_unit_),
                      "create io unit")) {
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
    UInt32 enable_output = 1;
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

    UInt32 size = sizeof(format_);
    // Set the format on the output scope of the input element/bus.
    if (CheckHasError(AudioUnitSetProperty(io_unit_, kAudioUnitProperty_StreamFormat,
                                        kAudioUnitScope_Output, kInputBus, &format_, size),
                   "set Property_StreamFormat on inputbus : output scope")) {
      return false;
    }

    // Set the format on the input scope of the output element/bus.
    if (CheckHasError(AudioUnitSetProperty(io_unit_, kAudioUnitProperty_StreamFormat,
                                        kAudioUnitScope_Input, kOutputBus, &format_, size),
                   "set Property_StreamFormat on outputbus : input scope")) {
      return false;
    }
    
    AURenderCallbackStruct render_callback;
    render_callback.inputProc = OnAskingForMoreDataForPlayingRenderCallback;
    render_callback.inputProcRefCon = this;
    if (CheckHasError(AudioUnitSetProperty(io_unit_,
                                           kAudioUnitProperty_SetRenderCallback,
                                           kAudioUnitScope_Input,
                                           kOutputBus,
                                           &render_callback,
                                           sizeof(render_callback)),
                   "set render callback on output bus: input scope")) {
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
    
    return true;
  }
  
  bool AudioUnitRecorderAndPlayerComplex::StartAudioUnit() {
    OSStatus result = AudioOutputUnitStart(io_unit_);
    if (result != noErr) {
      NSLog(@"======error AudioOutputUnitStart(), %@", @(result));
      return false;
    }
    return true;

  }
  
  void AudioUnitRecorderAndPlayerComplex::StopAudioUnit() {
    CheckHasError(AudioOutputUnitStop(io_unit_), "stop io unit");
    CheckHasError(AudioUnitUninitialize(io_unit_), "deinit io unit");
    CheckHasError(AudioComponentInstanceDispose(io_unit_), "dispose io unit");

  }
  
  
  OSStatus AudioUnitRecorderAndPlayerComplex::OnIOUnitRenderNotify(void *              inRefCon,
                                        AudioUnitRenderActionFlags *  ioActionFlags,
                                        const AudioTimeStamp *      inTimeStamp,
                                        UInt32              inBusNumber,
                                        UInt32              inNumberFrames,
                                        AudioBufferList *        ioData) {
    AudioUnitRecorderAndPlayerComplex *rec_and_player = static_cast<AudioUnitRecorderAndPlayerComplex *>(inRefCon);
    AudioUnitRenderActionFlags flags = *ioActionFlags;
    if (flags & kAudioUnitRenderAction_PostRenderError) {
      OSStatus ret = noErr;
      UInt32 size = sizeof(OSStatus);
      OSStatus status = AudioUnitGetProperty(rec_and_player->io_unit_, kAudioUnitProperty_LastRenderError, kAudioUnitScope_Global, kOutputBus, &ret, &size);
      NSLog(@"======PostRenderError, get status: %@, last render error ret: %@", @(status), @(ret));
    }
    return noErr;
  }

  OSStatus AudioUnitRecorderAndPlayerComplex::OnAskingForMoreDataForPlayingRenderCallback(void *              inRefCon,
                                        AudioUnitRenderActionFlags *  ioActionFlags,
                                        const AudioTimeStamp *      inTimeStamp,
                                        UInt32              inBusNumber,
                                        UInt32              inNumberFrames,
                                        AudioBufferList *        ioData) {
    AudioUnitRecorderAndPlayerComplex *rec_and_player = static_cast<AudioUnitRecorderAndPlayerComplex *>(inRefCon);
//    for (UInt32 i = 0; i< ioData->mNumberBuffers; ++i) {
//      memcpy(ioData->mBuffers[i].mData,
//             rec_and_player->buffer_.mBuffers[i].mData,
//             rec_and_player->buffer_.mBuffers[i].mDataByteSize);
//    }
    if (rec_and_player->ask_for_audio_buffer_callback_) {
      rec_and_player->ask_for_audio_buffer_callback_(*ioData);
    }
    return noErr;
  }

  OSStatus AudioUnitRecorderAndPlayerComplex::OnRecordedDataIsAvailable(void *              inRefCon,
                                           AudioUnitRenderActionFlags *  ioActionFlags,
                                           const AudioTimeStamp *      inTimeStamp,
                                           UInt32              inBusNumber,
                                           UInt32              inNumberFrames,
                                           AudioBufferList *        ioData) {
    AudioUnitRecorderAndPlayerComplex *rec_and_player = static_cast<AudioUnitRecorderAndPlayerComplex *>(inRefCon);
    OSStatus status = AudioUnitRender(rec_and_player->io_unit_, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &rec_and_player->buffer_);
    if (status != noErr) {
      NSLog(@"======AudioUnitRender error: %@", @(status));
    } else {
      if (rec_and_player->recorded_audio_buffer_callback_) {
        rec_and_player->recorded_audio_buffer_callback_(rec_and_player->buffer_);
      }
    }
    
    return status;
  }
}

