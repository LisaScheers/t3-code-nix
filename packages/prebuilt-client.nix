{
  appimageTools,
  fetchurl,
  lib,
  makeWrapper,
  stdenv,
  stdenvNoCC,
  unzip,
  release,
}:
let
  pname = "t3code";
  inherit (release) version;
  asset = release.client.${stdenv.hostPlatform.system};
  src = fetchurl {
    inherit (asset) url hash;
  };
  meta = {
    description = "T3 Code desktop client from the official release artifact";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/${release.tag}";
    license = lib.licenses.mit;
    mainProgram = "t3code";
    platforms = builtins.attrNames release.client;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };

  linuxContents = appimageTools.extract {
    inherit pname src version;
  };

  linuxPackage = appimageTools.wrapType2 {
    inherit pname src version;
    nativeBuildInputs = [ makeWrapper ];

    extraInstallCommands = ''
      mkdir -p "$out/share"
      if [ -d ${linuxContents}/usr/share ]; then
        cp -r ${linuxContents}/usr/share/* "$out/share/"
      fi

      desktop_file="$(find "$out/share" -type f -name '*.desktop' | head -n 1 || true)"
      if [ -n "$desktop_file" ]; then
        substituteInPlace "$desktop_file" \
          --replace-warn 'Exec=AppRun' 'Exec=t3code' \
          --replace-warn 'TryExec=AppRun' 'TryExec=t3code'
      fi

      wrapProgram "$out/bin/t3code" \
        --set T3CODE_DISABLE_AUTO_UPDATE 1 \
        --prefix XDG_DATA_DIRS : "$out/share"
    '';

    passthru.extracted = linuxContents;
    inherit meta;
  };

  appName =
    if lib.hasInfix "-nightly." version then "T3 Code (Nightly).app" else "T3 Code (Alpha).app";
  executable = lib.removeSuffix ".app" appName;
  darwinPackage = stdenvNoCC.mkDerivation {
    inherit pname src version;
    nativeBuildInputs = [
      makeWrapper
      unzip
    ];
    sourceRoot = ".";
    dontConfigure = true;
    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications" "$out/bin" "$out/libexec"
      # macOS may protect real Applications/*.app directories with com.apple.macl,
      # which prevents Nix from normalizing their permissions.
      mv ${lib.escapeShellArg appName} "$out/libexec/t3code"
      ln -s ../libexec/t3code "$out/Applications/${appName}"
      makeWrapper \
        "$out/Applications/${appName}/Contents/MacOS/${executable}" \
        "$out/bin/t3code" \
        --set T3CODE_DISABLE_AUTO_UPDATE 1

      runHook postInstall
    '';

    inherit meta;
  };
in
if stdenv.hostPlatform.isLinux then linuxPackage else darwinPackage
