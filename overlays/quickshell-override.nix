inputs: self: super: {
  quickshell = (import inputs.nixpkgs { inherit (self) system; }).quickshell;
}
