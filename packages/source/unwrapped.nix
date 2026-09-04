{
  cacert,
  cctools,
  copyDesktopItems,
  electron,
  fetchFromGitHub,
  fetchPnpmDeps,
  installShellFiles,
  lib,
  libicns,
  makeBinaryWrapper,
  makeDesktopItem,
  node-gyp,
  nodejs_24,
  pnpm_11,
  pnpmBuildHook,
  pnpmConfigHook,
  python3,
  stdenv,
  writeDarwinBundle,
  xcbuild,
  release,
}:
let
  appName = "T3 Code (Alpha)";
  pnpm = pnpm_11;
  src = fetchFromGitHub {
    owner = "pingdotgg";
    repo = "t3code";
    inherit (release) tag;
    hash = release.srcHash;
  };
  desktopIcon =
    if stdenv.hostPlatform.isDarwin then
      "assets/prod/black-macos-1024.png"
    else
      "assets/prod/black-universal-1024.png";
in
assert lib.versions.major electron.version == lib.versions.major release.electronVersion;
assert lib.versions.major pnpm.version == lib.versions.major release.pnpmVersion;
stdenv.mkDerivation (finalAttrs: {
  pname = "t3code-source-unwrapped";
  inherit (release) version;
  inherit src;
  strictDeps = true;
  __structuredAttrs = true;

  postPatch = ''
    substituteInPlace apps/web/vite.config.ts \
      --replace-fail 'const host = explicitHost || "localhost";' \
                     'const host = explicitHost || "127.0.0.1";'
  '';

  nativeBuildInputs = [
    cacert
    installShellFiles
    makeBinaryWrapper
    node-gyp
    nodejs_24
    pnpm
    pnpmBuildHook
    pnpmConfigHook
    python3
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ copyDesktopItems ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools.libtool
    libicns
    writeDarwinBundle
    xcbuild
  ];

  pnpmWorkspaces = [
    "@t3tools/monorepo"
    "t3..."
    "@t3tools/desktop..."
    "@t3tools/scripts..."
  ];
  pnpmDeps = fetchPnpmDeps {
    inherit pnpm src;
    inherit (finalAttrs)
      pname
      version
      pnpmWorkspaces
      ;
    fetcherVersion = 4;
    hash = release.pnpmHash;
  };

  preBuild = ''
    export pnpm_config_verify_deps_before_run=false
    node scripts/update-release-package-versions.ts ${release.version}
    export npm_config_nodedir=${nodejs_24}
    export ELECTRON_SKIP_BINARY_DOWNLOAD=1
    pnpm rebuild --pending "''${pnpmInstallFlags[@]}" --filter '!@t3tools/monorepo'
  '';

  pnpmBuildScript = "build:desktop";
  postBuild = "pnpm vp cache clean";
  dontPatchELF = true;
  dontStrip = true;
  noAuditTmpdir = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec/t3code/apps/desktop" "$out/libexec/t3code/apps/server"
    cp -r --no-preserve=mode node_modules "$out/libexec/t3code"
    cp -r --no-preserve=mode apps/server/{node_modules,dist} "$out/libexec/t3code/apps/server"
    cp -r --no-preserve=mode \
      apps/desktop/{package.json,node_modules,dist-electron} \
      "$out/libexec/t3code/apps/desktop"

    mkdir -p "$out/libexec/t3code/apps/desktop/prod-resources"
    install -m444 ${desktopIcon} \
      "$out/libexec/t3code/apps/desktop/prod-resources/icon.png"
    find "$out/libexec/t3code" -xtype l -delete

    makeWrapper ${lib.getExe nodejs_24} "$out/bin/t3" \
      --add-flags "$out/libexec/t3code/apps/server/dist/bin.mjs" \
      --set T3CODE_DISABLE_AUTO_UPDATE 1
    makeWrapper ${lib.getExe electron} "$out/bin/t3code" \
      --add-flags "$out/libexec/t3code/apps/desktop" \
      --inherit-argv0 \
      --set T3CODE_DISABLE_AUTO_UPDATE 1
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    find "$out/libexec/t3code" \
      -path '*/node-pty/prebuilds/darwin-*/spawn-helper' \
      -exec chmod 755 {} +

    mkdir -p "$out/Applications/${appName}.app/Contents/"{MacOS,Resources}
    png2icns "$out/Applications/${appName}.app/Contents/Resources/t3code.icns" ${desktopIcon}
    ${stdenv.shell} ${lib.getExe writeDarwinBundle} \
      "$out" "${appName}" t3code t3code
  ''
  + ''
    mkdir -p "$out/share/icons/hicolor/scalable/apps"
    install -m444 ${desktopIcon} "$out/share/icons/t3code.png"
    install -m444 assets/prod/logo.svg "$out/share/icons/hicolor/scalable/apps/t3code.svg"

    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    for shell in bash fish zsh; do
      installShellCompletion --cmd t3 --"$shell" <("$out/bin/t3" --completions "$shell")
    done
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "t3code";
      desktopName = appName;
      comment = "Web GUI for coding agents";
      exec = "t3code %U";
      terminal = false;
      icon = "t3code";
      startupWMClass = "t3code";
      categories = [ "Development" ];
    })
  ];

  passthru = {
    inherit release;
    pnpmDeps = finalAttrs.pnpmDeps;
  };

  meta = {
    description = "T3 Code client and server built from source";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/${release.tag}";
    license = lib.licenses.mit;
    mainProgram = "t3code";
    inherit (nodejs_24.meta) platforms;
  };
})
