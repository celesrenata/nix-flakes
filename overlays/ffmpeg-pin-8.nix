# Pin specific packages to ffmpeg 8 that break with ffmpeg 9.
# Do NOT override the global ffmpeg — that would invalidate the binary cache
# for heavy packages like qtwebengine (which triggers a GCC 15 ICE on rebuild).
#
# Affected packages:
#   - moonlight-qt: AVVulkanDeviceContext struct changes in ffmpeg 9
#   - wf-recorder: codec->pix_fmts/sample_fmts/ch_layouts removed in ffmpeg 9
#
# Re-evaluate when upstream consumers add ffmpeg 9 support.
final: prev: {
  moonlight-qt = prev.moonlight-qt.override {
    ffmpeg = prev.ffmpeg_8;
  };

  wf-recorder = prev.wf-recorder.override {
    ffmpeg = prev.ffmpeg_8;
  };
}
