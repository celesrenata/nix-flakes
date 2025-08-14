self: super: {
  pipewire = super.pipewire.override {
    # Remove problematic parameters and use only known working ones
    # withAlsa = true;
    # You may also want PulseAudio emulation and JACK:
    # withPulseaudio = true;
    # withJack = true;
  };

  wireplumber = super.wireplumber.override {
    # Make sure WirePlumber matches your new PipeWire build
    pipewire = self.pipewire;
  };
}

