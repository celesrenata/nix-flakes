final: prev: {
  steamtinkerlaunch =
    let
      unwrapped = prev.steamtinkerlaunch;
    in
    final.writeShellScriptBin "steamtinkerlaunch" ''
      exec ${final.steam-run}/bin/steam-run ${unwrapped}/bin/steamtinkerlaunch "$@"
    '' // {
      inherit (unwrapped) meta steamcompattool;
    };
}
