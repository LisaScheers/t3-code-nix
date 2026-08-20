# --- flake-parts/overlays/default.nix
{ ... }:
{
  flake.overlays.default = final: _prev: import ../../packages { pkgs = final; };
}
