final: prev: let
  wivrn-patched = prev.wivrn.overrideAttrs (oldAttrs: {
    postPatch = (oldAttrs.postPatch or "") + ''
      sed -i 's/FF_PROFILE_H264_CONSTRAINED_BASELINE/AV_PROFILE_H264_CONSTRAINED_BASELINE/g' server/encoder/ffmpeg/video_encoder_va.cpp
      sed -i 's/FF_PROFILE_HEVC_MAIN_10/AV_PROFILE_HEVC_MAIN_10/g' server/encoder/ffmpeg/video_encoder_va.cpp
      sed -i 's/FF_PROFILE_HEVC_MAIN/AV_PROFILE_HEVC_MAIN/g' server/encoder/ffmpeg/video_encoder_va.cpp
      sed -i 's/FF_PROFILE_AV1_MAIN/AV_PROFILE_AV1_MAIN/g' server/encoder/ffmpeg/video_encoder_va.cpp
    '';
  });
in {
  wivrn = prev.symlinkJoin {
    name = "wivrn-wrapped";
    paths = [ wivrn-patched ];
    buildInputs = [ prev.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/wivrn-server \
        --prefix LD_LIBRARY_PATH : ${prev.gcc15Stdenv.cc.cc.lib}/lib
    '';
  };
}
