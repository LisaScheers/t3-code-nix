{
  autoPatchelfHook,
  fetchurl,
  lib,
  makeWrapper,
  stdenv,
  channel,
  release,
}:
stdenv.mkDerivation {
  pname = if channel == "stable" then "t3code-server" else "t3code-server-nightly";
  inherit (release) version;
  src = fetchurl {
    inherit (release.server.${stdenv.hostPlatform.system}) url hash;
  };
  dontBuild = true;
  # Stripping the compiled executable removes its embedded application payload.
  dontStrip = true;
  dontPatchELF = true;
  dontAutoPatchelf = true;
  nativeBuildInputs = [ makeWrapper ] ++ lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;
  buildInputs = lib.optional stdenv.hostPlatform.isLinux stdenv.cc.cc.lib;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/t3code" "$out/bin"
    cp -r . "$out/lib/t3code/"
    makeWrapper "$out/lib/t3code/t3" "$out/bin/t3" \
      --set T3CODE_DISABLE_AUTO_UPDATE 1 \
      ${lib.optionalString stdenv.hostPlatform.isLinux "--prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [ stdenv.cc.cc.lib ]
      }"}

    runHook postInstall
  '';

  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    # Rewriting the SEA executable's RPATH corrupts its load segments.
    patchelf --set-interpreter ${stdenv.cc.bintools.dynamicLinker} "$out/lib/t3code/t3"
    autoPatchelf "$out/lib/t3code/node_modules" "$out/lib/t3code/resource-monitor"
  '';

  meta = {
    description = "T3 Code headless server from the official release artifact";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/${release.tag}";
    license = lib.licenses.mit;
    mainProgram = "t3";
    platforms = builtins.attrNames release.server;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
