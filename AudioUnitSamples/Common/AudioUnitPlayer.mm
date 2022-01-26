//
//  AudioUnitPlayer.m
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/26.
//

#import "AudioUnitPlayer.h"

namespace samples {

AudioUnitPlayer::AudioUnitPlayer(AudioStreamBasicDescription format) :
    audio_format_(format) {
  audio_buffer_list_.mNumberBuffers = 1;
  audio_buffer_list_.mBuffers[0].mNumberChannels = format.mChannelsPerFrame;
//    size_t bytes_per_frame = format.mChannelsPerFrame * format.mBytesPerFrame * format.mChannelsPerFrame;
//    size_t size = kPreferredSampleRate * kPreferredIOBufferDuration * bytes_per_frame;
  // TODO (xueshi) should be computed at runtime, not magic number
  audio_buffer_list_.mBuffers[0].mDataByteSize = 512; //size;
  audio_buffer_list_.mBuffers[0].mData =
      malloc(audio_buffer_list_.mBuffers[0].mDataByteSize);
};

bool AudioUnitPlayer::SetUpAudioUnit() {
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
  // 因为只播放, 所以不需要打开 input
  UInt32 enable_input = 0;
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
  
  /// Render Callback 是 IO unit 的 outpus 回调我们, 请求要播放的数据的回调, 我们在这个
  /// 回调里, 填充满 ioData, 这部分数据将会被播放出来
  /// 如果想静音的话, flag 需要设置为 kAudioUnitRenderAction_OutputIsSilence, 并且把
  /// ioData 的数据全置为 0.
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
  
  if (CheckHasError(AudioUnitAddRenderNotify(io_unit_, ioUnitRenderNotify, this), "add Render notify")) {
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

bool AudioUnitPlayer::StartAudioUnit() {
  std::cout << "======start audio unit" << std::endl;
  return AudioOutputUnitStart(io_unit_);
}

void AudioUnitPlayer::StopAudioUnit() {
  std::cout << "======stop audio unit" << std::endl;
  on_ask_audio_buffer_callback_ = nullptr;
  CheckHasError(AudioOutputUnitStop(io_unit_), "stop io unit");
  CheckHasError(AudioUnitUninitialize(io_unit_), "deinit io unit");
  CheckHasError(AudioComponentInstanceDispose(io_unit_), "dispose io unit");
}

OSStatus AudioUnitPlayer::OnAskingForMoreDataForPlayingRenderCallback(
                                                                      void * inRefCon,
                                                                      AudioUnitRenderActionFlags *ioActionFlags,
                                                                      const AudioTimeStamp *inTimeStamp,
                                                                      UInt32 inBusNumber,
                                                                      UInt32 inNumberFrames,
                                                                      AudioBufferList *ioData) {
  AudioUnitPlayer *player = static_cast<AudioUnitPlayer*>(inRefCon);
  bool eof = false;
  player->on_ask_audio_buffer_callback_(ioData->mBuffers[0].mData,
                                        ioData->mBuffers[0].mDataByteSize,
                                        eof);
  if (eof) {
    //...
  }
  //  samples::AudioUnitPlayer *wrapper = static_cast<samples::AudioUnitPlayer *>(inRefCon);
  //  OSStatus status = CheckErrorStatus(AudioUnitRender(wrapper->io_unit_, ioActionFlags, inTimeStamp,
  //                         inBusNumber, inNumberFrames, &wrapper->audio_buffer_list_),
  //                          "AudioUnitRender call");
  //  if (status == noErr && wrapper->on_record_callback_) {
  //    wrapper->on_record_callback_(wrapper->audio_buffer_list_);
  //  }
  return noErr;
}

OSStatus AudioUnitPlayer::ioUnitRenderNotify(void *              inRefCon,
                                      AudioUnitRenderActionFlags *  ioActionFlags,
                                      const AudioTimeStamp *      inTimeStamp,
                                      UInt32              inBusNumber,
                                      UInt32              inNumberFrames,
                                      AudioBufferList *        ioData)
{
//    // !!! this method is timing sensitive, better not add any wasting time code here, even nslog
//    if (*ioActionFlags & kAudioUnitRenderAction_PostRender) {
//    }
  AudioUnitPlayer *player = static_cast<AudioUnitPlayer*>(inRefCon);
    AudioUnitRenderActionFlags flags = *ioActionFlags;
//    @constant        kAudioUnitRenderAction_PostRenderError
//                    If this flag is set on the post-render call an error was returned by the
//                    AUs render operation. In this case, the error can be retrieved through the
//                    lastRenderError property and the audio data in ioData handed to the post-render
//                    notification will be invalid.

    if (flags & kAudioUnitRenderAction_PostRenderError) {
        OSStatus ret;
        UInt32 size = sizeof(OSStatus);
//        OSStatus result = AudioUnitGetProperty(_audioUnit,
//            kAudioUnitProperty_LastRenderError, kAudioUnitScope_Global, 0, &ret, &size);
//
        OSStatus status = AudioUnitGetProperty(player->io_unit_, kAudioUnitProperty_LastRenderError, kAudioUnitScope_Global, kOutputBus, &ret, &size);
        NSLog(@"======status: %@, ret: %@", @(status), @(ret));
    }
    return noErr;
}


}  // namespace samples
