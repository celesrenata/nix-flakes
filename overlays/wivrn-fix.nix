final: prev: {
  wivrn = prev.wivrn.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      # Fix FFmpeg profile constants
      sed -i 's/FF_PROFILE_H264_CONSTRAINED_BASELINE/AV_PROFILE_H264_CONSTRAINED_BASELINE/g' server/encoder/ffmpeg/video_encoder_va.cpp
      sed -i 's/FF_PROFILE_HEVC_MAIN_10/AV_PROFILE_HEVC_MAIN_10/g' server/encoder/ffmpeg/video_encoder_va.cpp
      sed -i 's/FF_PROFILE_HEVC_MAIN/AV_PROFILE_HEVC_MAIN/g' server/encoder/ffmpeg/video_encoder_va.cpp
      sed -i 's/FF_PROFILE_AV1_MAIN/AV_PROFILE_AV1_MAIN/g' server/encoder/ffmpeg/video_encoder_va.cpp
    '';
  });
}
