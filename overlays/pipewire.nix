self: super: {
  pipewire = super.pipewire.override {
    # In most Nixpkgs of 1.4.x, the boolean is called `withAlsa` (not `alsaSupport`)
    alsaSupport = true;
    # You may also want PulseAudio emulation and JACK:
    withPulseaudio = true;
    withJack      = true;
  };

  wireplumber = super.wireplumber.override {
    # Make sure WirePlumber matches your new PipeWire build
    pipewire = self.pipewire;
  };
}

