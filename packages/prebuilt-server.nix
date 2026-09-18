{
  buildNpmPackage,
  fetchurl,
  lib,
  makeWrapper,
  nodejs_24,
  stdenv,
  channel,
  npmProject,
  release,
}:
let
  npmPlatform =
    {
      aarch64-darwin = "darwin-arm64";
      aarch64-linux = "linux-arm64";
      x86_64-linux = "linux-x64";
    }
    .${stdenv.hostPlatform.system};
  platformPackage =
    (builtins.fromJSON (builtins.readFile "${npmProject}/package-lock.json"))
    .packages."node_modules/@t3code/t3-${npmPlatform}";
  platformArchive = fetchurl {
    url = platformPackage.resolved;
    hash = platformPackage.integrity;
  };
in
buildNpmPackage {
  pname = if channel == "stable" then "t3code-server" else "t3code-server-nightly";
  inherit (release) version;
  src = npmProject;
  nodejs = nodejs_24;
  npmDepsHash = release.npmHash;
  dontNpmBuild = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/t3code" "$out/bin"
    mkdir -p "node_modules/@t3code/t3-${npmPlatform}"
    tar -xzf ${platformArchive} \
      --strip-components=1 \
      -C "node_modules/@t3code/t3-${npmPlatform}"
    cp -r node_modules "$out/lib/t3code/"
    makeWrapper ${lib.getExe nodejs_24} "$out/bin/t3" \
      --add-flags "$out/lib/t3code/node_modules/t3/dist/bin.mjs" \
      --set T3CODE_DISABLE_AUTO_UPDATE 1

    runHook postInstall
  '';

  meta = {
    description = "T3 Code headless server from the exact npm release";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/${release.tag}";
    license = lib.licenses.mit;
    mainProgram = "t3";
    platforms = lib.platforms.unix;
  };
}
