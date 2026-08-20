{
  lib,
  makeBinaryWrapper,
  symlinkJoin,
  release,
  resourceMonitor,
  sourceUnwrapped,
}:
symlinkJoin {
  pname = "t3code-server-source";
  inherit (release) version;
  paths = [
    sourceUnwrapped
    resourceMonitor
  ];
  nativeBuildInputs = [ makeBinaryWrapper ];
  postBuild = ''
    rm "$out/bin/t3code"
    wrapProgram "$out/bin/t3" \
      --set T3CODE_DISABLE_AUTO_UPDATE 1 \
      --set-default T3CODE_RESOURCE_MONITOR_PATH ${lib.getExe resourceMonitor}
  '';
  passthru = {
    inherit release resourceMonitor sourceUnwrapped;
  };
  meta = sourceUnwrapped.meta // {
    description = "T3 Code headless server built from source";
    mainProgram = "t3";
  };
}
