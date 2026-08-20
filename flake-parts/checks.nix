{
  inputs,
  lib,
  self,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      homeDirectory = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/test" else "/home/test";
      clientVariant = if system == "aarch64-linux" then "source" else "prebuilt";
      mkHome =
        extraModule:
        inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            self.homeModules.t3code
            {
              home = {
                username = "test";
                inherit homeDirectory;
                stateVersion = "25.05";
              };
            }
            extraModule
          ];
        };
      matching = mkHome {
        programs.t3code = {
          enable = true;
          packageVariant = clientVariant;
        };
        services.t3code.enable = true;
      };
      mismatched = mkHome {
        programs.t3code = {
          enable = true;
          package = self.packages.${system}.t3code-source;
        };
        services.t3code = {
          enable = true;
          package = self.packages.${system}.t3code-server-nightly-source;
        };
      };
      matchingAssertionsPass = lib.all (entry: entry.assertion) matching.config.assertions;
      mismatchRejected = !(builtins.tryEval mismatched.activationPackage.drvPath).success;
      serviceDefined =
        if pkgs.stdenv.hostPlatform.isDarwin then
          matching.config.launchd.agents ? t3code
        else
          matching.config.systemd.user.services ? t3code;
      unsupportedArmPrebuiltRejected =
        if system != "aarch64-linux" then
          true
        else
          let
            unsupported = mkHome { programs.t3code.enable = true; };
          in
          !(builtins.tryEval unsupported.activationPackage.drvPath).success;
    in
    {
      checks.home-module =
        assert matchingAssertionsPass;
        assert mismatchRejected;
        assert serviceDefined;
        assert unsupportedArmPrebuiltRejected;
        pkgs.runCommand "t3code-home-module-evaluation" { } "touch $out";
    };
}
