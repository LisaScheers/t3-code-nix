{
  lib,
  makeBinaryWrapper,
  symlinkJoin,
  release,
  resourceMonitor,
  sourceUnwrapped,
}:
symlinkJoin {
  pname = "t3code-source";
  inherit (release) version;
  paths = [
    sourceUnwrapped
    resourceMonitor
  ];
  nativeBuildInputs = [ makeBinaryWrapper ];
  postBuild = ''
    for program in t3 t3code; do
      wrapProgram "$out/bin/$program" \
        --set T3CODE_DISABLE_AUTO_UPDATE 1 \
        --set-default T3CODE_RESOURCE_MONITOR_PATH ${lib.getExe resourceMonitor}
    done
  '';
  passthru = {
    inherit release resourceMonitor sourceUnwrapped;
  };
  meta = sourceUnwrapped.meta;
}
