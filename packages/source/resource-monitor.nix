{
  rustPlatform,
  release,
  sourceUnwrapped,
}:
rustPlatform.buildRustPackage {
  pname = "t3code-resource-monitor";
  inherit (release) version;
  inherit (sourceUnwrapped) src;
  sourceRoot = "${sourceUnwrapped.src.name}/native/resource-monitor";
  cargoHash = release.cargoHash;
  noAuditTmpdir = true;
  meta = sourceUnwrapped.meta // {
    description = "Native resource monitor for T3 Code";
    mainProgram = "t3-resource-monitor";
  };
}
