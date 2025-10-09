final: prev: {
  linuxPackages_t2 = prev.linuxPackages_t2.extend (lpfinal: lpprev: {
    kernel = lpprev.kernel.override {
      structuredExtraConfig = with prev.lib.kernel; {
        # Disable nouveau driver that conflicts with T2 patches
        DRM_NOUVEAU = no;
        DRM_NOUVEAU_BACKLIGHT = no;
      };
    };
  });
}
