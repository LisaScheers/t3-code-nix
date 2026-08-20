# --- flake-parts/pkgs/default.nix
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      t3codePackages = import ../../packages { inherit pkgs; };
    in
    {
      formatter = pkgs.nixfmt;
      packages = t3codePackages;
    };
}
