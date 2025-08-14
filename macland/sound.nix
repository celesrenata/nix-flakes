# SPDX-License-Identifier: MIT
# (C) 2022 The Asahi Linux Contributors

{ config, lib, pkgs, pkgs-old, ... }:

let
  t2AppleAudioDSP = pkgs.fetchFromGitHub {
    owner = "lemmyg";
    repo = "t2-apple-audio-dsp";
    rev = "fdd10303c8e84d09cf31e8cd88a624a34b9ed186";
    sha256 = "UnoZMONaYyhXkntTN+iUwcyjSquIgcw/Tw+ooNX9CzA=";
  };
  newTweeterFilePath = "${t2AppleAudioDSP}/firs/macbook_pro_t2_16_1_tweeters-48k_4.wav";
  newWooferFilePath = "${t2AppleAudioDSP}/firs/macbook_pro_t2_16_1_woofers-48k_4.wav";
in
{
  # Set microphone volume boost permanently
  systemd.user.services.boost-microphone = {
    description = "Boost microphone volume";
    wantedBy = [ "pipewire.service" ];
    after = [ "pipewire.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.pulseaudio}/bin/pactl set-source-volume alsa_input.pci-0000_04_00.3.BuiltinMic 200%";
      ExecStartPost = "${pkgs.coreutils}/bin/sleep 2";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  systemd.user.services.pipewire = {
    environment = {
      LV2_PATH = lib.mkForce "${config.system.path}/lib/lv2";
      LADSPA_PATH = lib.mkForce "${pkgs-old.ladspaPlugins}/lib/ladspa";
    };
  };

  services.pipewire.wireplumber.configPackages = [
	(pkgs.writeTextDir "share/pipewire/pipewire.conf.d/10-t2_161_sink.conf" ''
		# SPDX-License-Identifier: MIT
# (C) 2022 The Asahi Linux Contributors

context.properties = {
    #log.level = 0
    #default.clock.rate = 48000
    #default.clock.allowed-rates = [ 44100 48000 ]
}

context.spa-libs = {
    audio.convert.* = audioconvert/libspa-audioconvert
    support.*       = support/libspa-support
}

context.modules = [
    { name = libpipewire-module-rt
        args = {
            audio.format    = F32
            audio.rate      = 48000
            nice.level    = -11
            rt.prio       = 88
            #rt.time.soft = -1
            #rt.time.hard = -1
        }
        flags = [ ifexists nofail ]
    }
    { name = libpipewire-module-filter-chain
        args = {
            audio.format    = F32
            audio.rate      = 48000
            audio.channels   = 1
            audio.position   = [MONO]
            node.description = "MacBook Pro T2 DSP Mic"
            media.name       = "MacBook Pro T2 DSP Mic"
            filter.graph = {
                nodes = [
                    {
                         type   = ladspa
                         name   = preamp
                         plugin = amp_1181
                         label  = amp
                         control = {"Amps gain (dB)" = 110}
                    }
                    {
                         type   = ladspa
                         name   = boost
                         plugin = amp_1181
                         label  = amp
                         control = {"Amps gain (dB)" = 35}
                    }
                    {
                        type   = ladspa
                        name   = rnnoise
                        plugin = "${pkgs-old.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so"
                        label  = noise_suppressor_mono
                        control = {
                            "VAD Threshold (%)" = 85.0
                        }
                    }
                    {
                         type   = ladspa
                         name   = compressor
                         plugin = sc4_1882
                         label  = sc4
                         control = { 
                         "RMS/peak" = 0 
                         "Attack time (ms)" = 50
                         "Release time (ms)" = 300
                         "Threshold level (dB)" = -12
                         "Ratio (1:n)" = 4
                         "Knee radius (dB)" = 3
                         "Makeup gain (dB)" = 5
                         }
                     }
                     {
                         type   = ladspa
                         name   = limiter
                         plugin = fast_lookahead_limiter_1913
                         label  = fastLookaheadLimiter
                         control = { "Input gain (dB)" = 0 "Limit (dB)" = -1 "Release time (s)" = 0.8 }
                     }
                ]
                links = [
                    { output = "preamp:Output" input = "boost:Input" }
                    { output = "boost:Output" input = "rnnoise:Input" }
                    { output = "rnnoise:Output" input = "compressor:Left input" }
                    { output = "compressor:Left output" input = "limiter:Input 1" }
                ]
                inputs = [ "preamp:Input" ]
                outputs = [ "limiter:Output 1"]
            }
            capture.props = {
                node.name        = "effect_input.filter-chain-mic"
                audio.position = [AUX1]
                stream.dont-remix = true
                node.target = "alsa_input.pci-0000_04_00.3.BuiltinMic"
                node.passive = true
            }
            playback.props = {
                node.name = "effect_output.filter-chain-mic"
                media.class = Audio/Source
                node.passive = true
                audio.position = [MONO]
            }
        }
        args = {
            node.description = "MacBook Pro T2 DSP Speakers"
            media.name       = "MacBook Pro T2 DSP Speakers"
            filter.graph = {
                nodes = [
                    {   
                        type = lv2
                        name = bass
                        plugin = "http://calf.sourceforge.net/plugins/BassEnhancer"
                        control = {
                            level_in = 1.0
                            level_out = 1.0
                            amount = 0.9
                            drive = 8.5
                            blend = -10.0
                            freq = 120
                            listen = 0
                            floor_active = 1
                            floor = 40
                        }
                    }
                    {
                        type = lv2
                        plugin = "http://lsp-plug.in/plugins/lv2/mb_compressor_stereo"
                        name = compressor
                        control = {
                            mode = 1
                            g_in = 1.0
                            g_out = 1.0
                            g_dry = 0.0
                            g_wet = 1.0
                            bsel = 0
                            flt = 1
                            ife_l = 0
                            ofe_l = 0
                            ife_r = 0
                            ofe_r = 0
                            ce_0 = 1
                            al_0 = 0.501187
                            at_0 = 0.0
                            rrl_0 = 0.00001
                            rt_0 = 750.0
                            cr_0 = 2.0
                            kn_0 = 0.501187
                            mk_0 = 1.0
                            sla_0 = 10.0
                            bs_0 = 0
                            bm_0 = 0
                            cbe_1 = 1
                            ce_1 = 1
                            sf_1 = 100
                            al_1 = 0.251189
                            at_1 = 0.0
                            rrl_1 = 0.00001
                            rt_1 = 750
                            cr_1 = 2.0
                            kn_1 = 0.251197
                            sla_1 = 10.0
                            mk_1 = 5.0
                            bs_1 = 0
                            bm_1 = 0
                            cbe_2 = 1
                            ce_2 = 1
                            sf_2 = 500
                            al_2 = 0.251189
                            at_2 = 0.0
                            rrl_2 = 0.00001
                            rt_2 = 750.0
                            cr_2 = 2.0
                            kn_2 = 0.251197
                            mk_2 = 4.5
                            sla_2 = 10.0
                            bs_2 = 0
                            bm_2 = 0
                            cbe_7 = 1
                            ce_7 = 1
                            sf_7 = 3000
                            al_7 = 0.251189
                            at_7 = 0.00001
                            rrl_7 = 750.0
                            cr_7 = 2.5
                            kn_7 = 0.251197
                            sla_7 = 10.0
                            mk_7 = 3.0
                            bs_7 = 0
                            bm_7 = 0
                            cbe_3 = 0
                            cbe_4 = 0
                            cbe_5 = 0
                            cbe_6 = 0
                        }
                    }
                    {
                        type   = ladspa
                        name   = limiter
                        plugin = fast_lookahead_limiter_1913
                        label  = fastLookaheadLimiter
                        control = { "Input gain (dB)" = 0 "Limit (dB)" = -1 "Release time (s)" = 0.8 }
                    }
                    {
                        type = builtin
                        label = convolver
                        name = convLT
                        config = {
                            filename = "${newTweeterFilePath}"
                            channel = 0
                            gain = 1.0
                        }
                    }
                    {
                        type = builtin
                        label = convolver
                        name = convRT
                        config = {
                            filename = "${newTweeterFilePath}"
                            channel = 0
                            gain = 1.0
                        }
                    }
                    {
                        type = builtin
                        label = convolver
                        name = convLW
                        config = {
                            filename = "${newWooferFilePath}"
                            channel = 0
                            gain = 1.0
                        }
                    }
                    {
                        type = builtin
                        label = convolver
                        name = convRW
                        config = {
                            filename = "${newWooferFilePath}"
                            channel = 0
                            gain = 1.0
                        }
                    }
                    { type = builtin label = copy name = inputL }
                    { type = builtin label = copy name = inputR }
                    { type = builtin label = copy name = LW }
                    { type = builtin label = copy name = LW2 }
                    { type = builtin label = copy name = LT }
                    { type = builtin label = copy name = RW }
                    { type = builtin label = copy name = RW2 }
                    { type = builtin label = copy name = RT }
                ]
                links = [
                    { output = "bass:out_l" input = "compressor:in_l"}
                    { output = "bass:out_r" input = "compressor:in_r"}
                    { output = "compressor:out_l" input = "limiter:Input 1"}
                    { output = "compressor:out_r" input = "limiter:Input 2"}
                    { output = "limiter:Output 1" input = "convLT:In"}
                    { output = "limiter:Output 1" input = "convLW:In"}
                    { output = "limiter:Output 2" input = "convRT:In"}
                    { output = "limiter:Output 2" input = "convRW:In"}
                    { output = "convLW:Out" input = "LW:In"}
                    { output = "convRW:Out" input = "RW:In"}
                    { output = "convLW:Out" input = "LW2:In"}
                    { output = "convRW:Out" input = "RW2:In"}
                ]
                inputs = [ "bass:in_l" "bass:in_r" ]
                outputs = [ 
                            "LW:Out"
                            "LW2:Out"
                            "convLT:Out"
                            "RW:Out"
                            "RW2:Out"
                            "convRT:Out"
                ]
            }
            capture.props = {
                node.name = "effect_input.filter-chain-speakers"
                media.class = Audio/Sink
                audio.channels = 2
                audio.position = [ FL FR ]
            }
            playback.props = {
                node.name = "effect_output.filter-chain-speakers"
                node.target = "alsa_output.pci-0000_04_00.3.Speakers"
                node.passive = true
                audio.channels = 6
                audio.position = [ AUX0 AUX1 AUX2 AUX3 AUX4 AUX5 ]
            }
        }
    }
]
	'')
  ];
}
