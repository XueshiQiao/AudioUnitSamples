//
//  AUGraphRecorderPlayer.m
//  AudioUnitSamples
//
//  Created by Joey on 2022/1/28.
//

#import "AUGraphRecorderPlayer.h"
#import "CommonUtils.h"

namespace samples {
    
AUGraphRecorderPlayer::AUGraphRecorderPlayer(AudioStreamBasicDescription format) : format_(format)  {
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
  
  CheckHasError(AUGraphConnectNodeInput(graph_, mixer_node_, 0, io_node_, 0),
                "Connect mixer_node_->output bus to io_node_->outputbus");
  
  CheckHasError(AUGraphOpen(graph_), "open graph");
  
  CheckHasError(AUGraphNodeInfo(graph_, io_node_, NULL, &io_unit_), "get io_unit_ from graph");
  CheckHasError(AUGraphNodeInfo(graph_, mixer_node_, NULL, &mixer_unit_), "get mixer_unit_ from graph");
  
  // config IO unit
  {
    UInt32 enable = 1;
    CheckHasError(AudioUnitSetProperty(io_unit_, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus, &enable, sizeof(enable)), "enable Input");

    CheckHasError(AudioUnitSetProperty(io_unit_, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, kInputBus, &format_, sizeof(AudioStreamBasicDescription)),
                  "set format on io_unit_:1:output_scope");
    
    AURenderCallbackStruct io_unit_input_callback {
      .inputProc = OnIOUnitAudioBufferIsAvailable,
      .inputProcRefCon = this
    };
    CheckHasError(AudioUnitSetProperty(io_unit_, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &io_unit_input_callback, sizeof(io_unit_input_callback)), "set input callback");
    
    CheckHasError(AudioUnitAddRenderNotify(io_unit_, OnIOUnitRenderNotify, this), "add Render notify");
  }
  
  // config mixer unit
  {
    UInt32 mixer_input_buses_num = 1;  // can be 2
    CheckHasError(AudioUnitSetProperty(mixer_unit_, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &mixer_input_buses_num, sizeof(mixer_input_buses_num)), "set mixer input bus count");

    // 指定 Input Scope 的 第 0 bus, 记住 mixer 的 input scope 有多个 bus, output scope 只有一个 bus
    CheckHasError(AudioUnitSetProperty(mixer_unit_, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &format_, sizeof(AudioStreamBasicDescription)),
                  "set format on mixex_unit_:0:input_scope");
    
    CheckHasError(AudioUnitSetProperty(mixer_unit_, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &format_, sizeof(AudioStreamBasicDescription)), "set format on mixer_unit_:output_bus:output_scope");
    
    AudioUnitParameterValue enable_mixer_input = 1;
    CheckHasError(AudioUnitSetParameter(mixer_unit_, kMultiChannelMixerParam_Enable, kAudioUnitScope_Input, 0, enable_mixer_input, 0), "enable mixer input 0");
    
    AURenderCallbackStruct mixer_vocal_input_bus0_render_callback {
        .inputProc = OnAskForVocalAudioBufferRenderCallback,
        .inputProcRefCon = this
      };
    CheckHasError(AUGraphSetNodeInputCallback(graph_, mixer_node_, 0, &mixer_vocal_input_bus0_render_callback),
                  "set mixer_vocal_input_bus0 render callback");
  }
  
  CheckHasError(AUGraphInitialize(graph_), "Initialize graph_");
  
  CAShow(graph_);
}

void AUGraphRecorderPlayer::Start() {
  if (IsRunning()) {
    return;
  }
  CheckHasError(AUGraphStart(graph_), "start augraph");
}

void AUGraphRecorderPlayer::Stop() {
  if (IsRunning()) {
    CheckHasError(AUGraphStop(graph_), "stop augraph");
  }
  
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

bool AUGraphRecorderPlayer::IsRunning() {
  return false;
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
  
OSStatus AUGraphRecorderPlayer::OnIOUnitAudioBufferIsAvailable(void *inRefCon,
  AudioUnitRenderActionFlags *ioActionFlags,
  const AudioTimeStamp *inTimeStamp,
  UInt32 inBusNumber,
  UInt32 inNumberFrames,
  AudioBufferList *ioData) {
  
  AUGraphRecorderPlayer *THIS = static_cast<AUGraphRecorderPlayer *>(inRefCon);
  OSStatus ret = CheckErrorStatus(AudioUnitRender(THIS->io_unit_, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &THIS->buffer_), "render input callback");
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
    OSStatus status = AudioUnitGetProperty(rec_and_player->io_unit_, kAudioUnitProperty_LastRenderError, kAudioUnitScope_Global, kOutputBus, &ret, &size);
    NSLog(@"======PostRenderError, get status: %@, last render error ret: %@", @(status), @(ret));
  }
  return noErr;
}

  
} // namespace samples
