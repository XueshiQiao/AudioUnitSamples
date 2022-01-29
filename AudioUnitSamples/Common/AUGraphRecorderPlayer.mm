//
//  AUGraphRecorderPlayer.m
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/28.
//

#import "AUGraphRecorderPlayer.h"
#import "CommonUtils.h"

namespace {

// mixer 的 input scope 有多个 input element:
// 我们定义 第 0 个为人声, 第 1 个为伴奏
constexpr UInt32 kMixerVocalInputElementNumber = 0;
constexpr UInt32 kMixerMusicInputElementNumber = 1;
  
// mixer 的 output scope 只有一个 element, number 自然为 0
constexpr UInt32 kMixerUniqueOutputElementNumber = 0;
};

namespace samples {
    
AUGraphRecorderPlayer::AUGraphRecorderPlayer(AudioStreamBasicDescription format, CFURLRef music_file_url) :
  format_(format), music_file_reader_(std::make_unique<AudioFileReader>(music_file_url, format)) {
  InitAudioBufferList(&buffer_);
}

AUGraphRecorderPlayer::~AUGraphRecorderPlayer() {
  if (IsRunning()) {
    Stop();
  }
  DisposeAudioBufferList(&buffer_);
}

void AUGraphRecorderPlayer::InitializeGraph() {
  CheckHasError(NewAUGraph(&graph_), "New AUGraph");
  
  // add io unit
  {
    AudioComponentDescription node_desc = {
      .componentType = kAudioUnitType_Output,
      .componentSubType = kAudioUnitSubType_RemoteIO,
      .componentManufacturer = kAudioUnitManufacturer_Apple,
      .componentFlags = kAudioComponentFlag_SandboxSafe,
      .componentFlagsMask = 0
    };
    CheckHasError(AUGraphAddNode(graph_, &node_desc, &io_node_), "Add output node");
  }
  
  // add mixer node
  {
    AudioComponentDescription node_desc = {
      .componentType = kAudioUnitType_Mixer,
      .componentSubType = kAudioUnitSubType_MultiChannelMixer,
      .componentManufacturer = kAudioUnitManufacturer_Apple,
      .componentFlags = kAudioComponentFlag_SandboxSafe,
      .componentFlagsMask = 0
    };
    CheckHasError(AUGraphAddNode(graph_, &node_desc, &mixer_node_), "Add mixer node");
  }
  
  // connect mixer node:[output_scope]:output_element  to io_unit:[input scope]:ouput_element
  // [] 为隐含含义, 因为肯定是连接前者的 output scope 到后者的 input scope, 这个是确定的,
  // 因为这两个 unit 的对应的 scope 对应的 element 都只有一个, 所以都是 0
  // mixer 的 output scope 对应的 element 只有一个, io unit 的 input scope 对应的 element 也只有一个
  CheckHasError(AUGraphConnectNodeInput(graph_, mixer_node_, kMixerUniqueOutputElementNumber, io_node_, 0),
                "Connect mixer_node_->output bus to io_node_->outputbus");
  
  CheckHasError(AUGraphOpen(graph_), "open graph");
  
  CheckHasError(AUGraphNodeInfo(graph_, io_node_, NULL, &io_unit_), "get io_unit_ from graph");
  CheckHasError(AUGraphNodeInfo(graph_, mixer_node_, NULL, &mixer_unit_), "get mixer_unit_ from graph");
  
  // config IO unit
  {
    UInt32 enable = 1;
    CheckHasError(AudioUnitSetProperty(io_unit_, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus,
                                       &enable, sizeof(enable)),
                  "enable IO unit Input");

    CheckHasError(AudioUnitSetProperty(io_unit_, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, kInputBus,
                                       &format_, sizeof(AudioStreamBasicDescription)),
                  "set format on io_unit_:1:output_scope");
    
    AURenderCallbackStruct io_unit_input_callback {
      .inputProc = OnIOUnitAudioBufferIsAvailable,
      .inputProcRefCon = this
    };
    CheckHasError(AudioUnitSetProperty(io_unit_, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global,
                                       0, &io_unit_input_callback, sizeof(io_unit_input_callback)), "set input callback");
    
    CheckHasError(AudioUnitAddRenderNotify(io_unit_, OnIOUnitRenderNotify, this), "add Render notify");
  }
  
  // config mixer unit
  {
    UInt32 mixer_input_buses_num = 2;  // can be 2
    // 这里的第 4 个参数 inElement 此处没有意义, 因为现在就是在设置 input element 的数量, 设置完了之后才有意义
    CheckHasError(AudioUnitSetProperty(mixer_unit_, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input,
                                       0, &mixer_input_buses_num, sizeof(mixer_input_buses_num)),
                  "set mixer input bus count");

    // 指定 Input Scope 的 第 0 bus, 记住 mixer 的 input scope 有多个 bus, output scope 只有一个 bus
    CheckHasError(AudioUnitSetProperty(mixer_unit_, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                                       kMixerVocalInputElementNumber, &format_, sizeof(AudioStreamBasicDescription)),
                  "set format on mixex_unit_:0:input_scope");
    
    CheckHasError(AudioUnitSetProperty(mixer_unit_, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input,
                                       kMixerMusicInputElementNumber, &format_, sizeof(AudioStreamBasicDescription)),
                  "set format on mixex_unit_:0:input_scope");

//    OnAskForMusicAudioBufferRenderCallback
    
    CheckHasError(AudioUnitSetProperty(mixer_unit_, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output,
                                       kMixerUniqueOutputElementNumber, &format_, sizeof(AudioStreamBasicDescription)),
                  "set format on mixer_unit_:output_bus:output_scope");
    
    AudioUnitParameterValue enable_mixer_input = 1;
    UInt32 in_buffer_offset_in_frames = 0;
    CheckHasError(AudioUnitSetParameter(mixer_unit_, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input,
                                        kMixerVocalInputElementNumber, enable_mixer_input, in_buffer_offset_in_frames),
                  "enable mixer input 0");

    CheckHasError(AudioUnitSetParameter(mixer_unit_, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input,
                                        kMixerMusicInputElementNumber, enable_mixer_input, in_buffer_offset_in_frames),
                  "enable mixer input 0");
    
    AURenderCallbackStruct mixer_vocal_input_element0_render_callback {
      .inputProc = OnAskForVocalAudioBufferRenderCallback,
      .inputProcRefCon = this
    };
    // Note:
    // 这里的 InputCallback 不等价于 AudioUnitSetProperty(unit, kAudioOutputUnitProperty_SetInputCallback, ...)
    // 而是等价于 AudioUnitSetProperty(unit, kAudioUnitProperty_SetRenderCallback, ...)
    CheckHasError(AUGraphSetNodeInputCallback(graph_, mixer_node_, kMixerVocalInputElementNumber, &mixer_vocal_input_element0_render_callback),
                  "set mixer_vocal_input_element0 render callback");
    
    AURenderCallbackStruct mixer_music_input_element1_render_callback {
      .inputProc = OnAskForMusicAudioBufferRenderCallback,
      .inputProcRefCon = this
    };
    CheckHasError(AUGraphSetNodeInputCallback(graph_, mixer_node_, kMixerMusicInputElementNumber, &mixer_music_input_element1_render_callback),
                  "set mixer_music_input_element1 render callback");
  }
  
  CheckHasError(AUGraphInitialize(graph_), "Initialize graph_");
  
  CAShow(graph_);
}

void AUGraphRecorderPlayer::Start() {
  if (IsRunning()) {
    return;
  }
  music_file_reader_->OpenFile();
  CheckHasError(AUGraphStart(graph_), "start augraph");
}

void AUGraphRecorderPlayer::Stop() {
  if (graph_ && IsRunning()) {
    CheckHasError(AUGraphStop(graph_), "stop augraph");
    music_file_reader_->CloseFile();
    
    Boolean graphIsInitialized;
    if (!CheckHasError(AUGraphIsInitialized(graph_, &graphIsInitialized), "check AUGraphIsInitialized")
        && graphIsInitialized) {
      CheckHasError(AUGraphUninitialize(graph_), "AUGraphUninitialize");
    }
    
    Boolean graphIsOpen;
    if (!CheckHasError(AUGraphIsOpen(graph_, &graphIsOpen), "check AUGraphIsOpen") && graphIsOpen) {
      CheckHasError(AUGraphClose(graph_), "AUGraphClose");
    }
    
    CheckHasError(DisposeAUGraph(graph_), "DisposeAUGraph");

    graph_ = NULL;
  }
}

bool AUGraphRecorderPlayer::IsRunning() {
  Boolean is_running = false;
  CheckHasError(AUGraphIsRunning(graph_, &is_running), "check is running");
  return (bool)is_running;
}

OSStatus AUGraphRecorderPlayer::OnAskForVocalAudioBufferRenderCallback(void *inRefCon,
                                                                       AudioUnitRenderActionFlags *ioActionFlags,
                                                                       const AudioTimeStamp *inTimeStamp,
                                                                       UInt32 inBusNumber,
                                                                       UInt32 inNumberFrames,
                                                                       AudioBufferList *ioData) {
  AUGraphRecorderPlayer *THIS = static_cast<AUGraphRecorderPlayer *>(inRefCon);
  CopyAudioBufferListDatas(*ioData, THIS->buffer_);
  return noErr;
}

OSStatus AUGraphRecorderPlayer::OnAskForMusicAudioBufferRenderCallback(void *inRefCon,
                                                                       AudioUnitRenderActionFlags *ioActionFlags,
                                                                       const AudioTimeStamp *inTimeStamp,
                                                                       UInt32 inBusNumber,
                                                                       UInt32 inNumberFrames,
                                                                       AudioBufferList *ioData) {
  AUGraphRecorderPlayer *THIS = static_cast<AUGraphRecorderPlayer *>(inRefCon);
  bool eof = false;
  THIS->music_file_reader_->ReadAudioFrame(ioData->mBuffers[0].mDataByteSize, ioData->mBuffers[0].mData, eof);
  return noErr;
}

OSStatus AUGraphRecorderPlayer::OnIOUnitAudioBufferIsAvailable(void *inRefCon,
                                                               AudioUnitRenderActionFlags *ioActionFlags,
                                                               const AudioTimeStamp *inTimeStamp,
                                                               UInt32 inBusNumber,
                                                               UInt32 inNumberFrames,
                                                               AudioBufferList *ioData) {
  
  AUGraphRecorderPlayer *THIS = static_cast<AUGraphRecorderPlayer *>(inRefCon);
  OSStatus ret = CheckErrorStatus(AudioUnitRender(THIS->io_unit_, ioActionFlags, inTimeStamp,
                                                  inBusNumber, inNumberFrames, &THIS->buffer_),
                                  "render input callback");
  return ret;
}

OSStatus AUGraphRecorderPlayer::OnIOUnitRenderNotify(void *              inRefCon,
                                                     AudioUnitRenderActionFlags *  ioActionFlags,
                                                     const AudioTimeStamp *      inTimeStamp,
                                                     UInt32              inBusNumber,
                                                     UInt32              inNumberFrames,
                                                     AudioBufferList *        ioData) {
  AUGraphRecorderPlayer *rec_and_player = static_cast<AUGraphRecorderPlayer *>(inRefCon);
  AudioUnitRenderActionFlags flags = *ioActionFlags;
  if (flags & kAudioUnitRenderAction_PostRenderError) {
    OSStatus ret = noErr;
    UInt32 size = sizeof(OSStatus);
    OSStatus status = CheckHasError(AudioUnitGetProperty(rec_and_player->io_unit_, kAudioUnitProperty_LastRenderError,
                                                         kAudioUnitScope_Global, kOutputBus, &ret, &size),
                                    "get last render error");
    NSLog(@"======PostRenderError, get status: %@, last render error ret: %@", @(status), @(ret));
  }
  return noErr;
}

  
} // namespace samples
