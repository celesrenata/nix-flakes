final: prev:
{
  android-studio-patched  = prev.android_studio_full {
    src = fetchurl {
      url = "https://dl.google.com/dl/android/studio/ide-zips/${version}/${filename}";
      sha256 = ;
    };
  };
}
