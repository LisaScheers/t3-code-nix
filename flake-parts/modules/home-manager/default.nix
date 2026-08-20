# --- flake-parts/modules/home-manager/default.nix
{
  lib,
  inputs,
  self,
  ...
}:
let
  inherit (inputs.flake-parts.lib) importApply;
  localFlake = self;
  t3codeModule = importApply ./t3code.nix { inherit localFlake; };
in
{
  options.flake.homeModules = lib.mkOption {
    type = with lib.types; lazyAttrsOf unspecified;
    default = { };
  };

  config.flake.homeModules = {
    default = t3codeModule;
    t3code = t3codeModule;
  };
}
