{ pkgs }:
let
  inherit (pkgs) lib;
  releases = import ../releases.nix;

  mkChannel =
    channel: release:
    let
      isStable = channel == "stable";
      clientName = if isStable then "t3code" else "t3code-nightly";
      serverName = if isStable then "t3code-server" else "t3code-server-nightly";
      sourceClientName = if isStable then "t3code-source" else "t3code-nightly-source";
      sourceServerName = if isStable then "t3code-server-source" else "t3code-server-nightly-source";

      sourceUnwrapped = pkgs.callPackage ./source/unwrapped.nix { inherit release; };
      resourceMonitor = pkgs.callPackage ./source/resource-monitor.nix {
        inherit release sourceUnwrapped;
      };
      sourceClient = pkgs.callPackage ./source/client.nix {
        inherit release resourceMonitor sourceUnwrapped;
      };
      sourceServer = pkgs.callPackage ./source/server.nix {
        inherit release resourceMonitor sourceUnwrapped;
      };
      prebuiltServer = pkgs.callPackage ./prebuilt-server.nix {
        inherit channel release;
        npmProject = ./npm + "/${channel}";
      };
      hasPrebuiltClient = builtins.hasAttr pkgs.stdenv.hostPlatform.system release.client;
      prebuiltClient = pkgs.callPackage ./prebuilt-client.nix { inherit release; };
    in
    {
      ${serverName} = prebuiltServer;
      ${sourceClientName} = sourceClient;
      ${sourceServerName} = sourceServer;
    }
    // lib.optionalAttrs hasPrebuiltClient {
      ${clientName} = prebuiltClient;
    };

  channelPackages = mkChannel "stable" releases.stable // mkChannel "nightly" releases.nightly;
in
channelPackages
// {
  default = channelPackages.t3code or channelPackages.t3code-source;
}
