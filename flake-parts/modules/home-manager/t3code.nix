{ localFlake }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  clientConfig = config.programs.t3code;
  serverConfig = config.services.t3code;

  system = pkgs.stdenv.hostPlatform.system;
  packageFromFlake = name: localFlake.packages.${system}.${name} or null;

  clientPackageName =
    if clientConfig.channel == "stable" then
      if clientConfig.packageVariant == "prebuilt" then "t3code" else "t3code-source"
    else if clientConfig.packageVariant == "prebuilt" then
      "t3code-nightly"
    else
      "t3code-nightly-source";
  serverPackageName =
    if serverConfig.channel == "stable" then
      if serverConfig.packageVariant == "prebuilt" then "t3code-server" else "t3code-server-source"
    else if serverConfig.packageVariant == "prebuilt" then
      "t3code-server-nightly"
    else
      "t3code-server-nightly-source";

  selectedClientPackage = packageFromFlake clientPackageName;
  selectedServerPackage = packageFromFlake serverPackageName;
  clientPackage = clientConfig.package;
  serverPackage = serverConfig.package;

  providerPath = lib.makeBinPath serverConfig.providerPackages;
  servicePath = lib.concatStringsSep ":" (
    lib.optional (providerPath != "") providerPath
    ++ [
      "%h/.nix-profile/bin"
      "/etc/profiles/per-user/%u/bin"
      "/run/current-system/sw/bin"
      "/usr/bin"
      "/bin"
    ]
  );
  serviceEnvironment = serverConfig.environment // {
    PATH = servicePath;
    T3CODE_DISABLE_AUTO_UPDATE = "1";
  };
  serviceArguments = [
    "${serverPackage}/bin/t3"
    "serve"
    "--host"
    serverConfig.host
    "--port"
    (toString serverConfig.port)
    "--base-dir"
    serverConfig.dataDirectory
  ]
  ++ serverConfig.extraArguments
  ++ [ serverConfig.workingDirectory ];
in
{
  options = {
    programs.t3code = {
      channel = mkOption {
        type = types.enum [
          "stable"
          "nightly"
        ];
        default = "stable";
        description = "Release channel to install.";
      };
      packageVariant = mkOption {
        type = types.enum [
          "prebuilt"
          "source"
        ];
        default = "prebuilt";
        description = "Use the official desktop artifact or the Nix source build.";
      };
    };

    services.t3code = {
      enable = mkEnableOption "the T3 Code headless server";
      channel = mkOption {
        type = types.enum [
          "stable"
          "nightly"
        ];
        default = "stable";
        description = "Release channel to run.";
      };
      packageVariant = mkOption {
        type = types.enum [
          "prebuilt"
          "source"
        ];
        default = "prebuilt";
        description = "Use the npm release or the Nix source build.";
      };
      package = mkOption {
        type = types.nullOr types.package;
        default = null;
        description = "Package override. This takes precedence over channel and packageVariant.";
      };
      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Address on which the server listens.";
      };
      port = mkOption {
        type = types.port;
        default = 3773;
        description = "HTTP and WebSocket port.";
      };
      dataDirectory = mkOption {
        type = types.str;
        default = "${config.xdg.dataHome}/t3code";
        defaultText = lib.literalExpression ''"\${config.xdg.dataHome}/t3code"'';
        description = "T3 Code data directory passed through --base-dir.";
      };
      workingDirectory = mkOption {
        type = types.str;
        default = config.home.homeDirectory;
        defaultText = lib.literalExpression "config.home.homeDirectory";
        description = "Working directory for provider sessions.";
      };
      providerPackages = mkOption {
        type = types.listOf types.package;
        default = [ ];
        example = lib.literalExpression "[ pkgs.codex pkgs.claude-code ]";
        description = "Provider CLI packages added to the service PATH.";
      };
      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Environment variables for the server process.";
      };
      extraArguments = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Extra arguments inserted before the working directory.";
      };
    };
  };

  config = lib.mkMerge [
    {
      programs.t3code.package = lib.mkDefault selectedClientPackage;
      services.t3code.package = lib.mkDefault selectedServerPackage;

      assertions = [
        {
          assertion = !clientConfig.enable || clientPackage != null;
          message = "programs.t3code selected an unsupported package combination. aarch64-linux requires packageVariant = \"source\" unless package is overridden.";
        }
        {
          assertion = !serverConfig.enable || serverPackage != null;
          message = "services.t3code could not resolve the selected server package.";
        }
        {
          assertion =
            !(clientConfig.enable && serverConfig.enable)
            || clientPackage == null
            || serverPackage == null
            || lib.getVersion clientPackage == lib.getVersion serverPackage;
          message = "programs.t3code and services.t3code must use packages from the same release version.";
        }
      ];
    }

    (mkIf (serverConfig.enable && serverPackage != null && pkgs.stdenv.hostPlatform.isLinux) {
      systemd.user.services.t3code = {
        Unit = {
          Description = "T3 Code server";
          After = [ "network.target" ];
        };
        Service = {
          ExecStart = lib.escapeShellArgs serviceArguments;
          Environment = lib.mapAttrsToList (name: value: "${name}=${value}") serviceEnvironment;
          Restart = "on-failure";
          RestartSec = 5;
          WorkingDirectory = serverConfig.workingDirectory;
        };
        Install.WantedBy = [ "default.target" ];
      };
    })

    (mkIf (serverConfig.enable && serverPackage != null && pkgs.stdenv.hostPlatform.isDarwin) {
      launchd.agents.t3code = {
        enable = true;
        config = {
          Label = "com.t3tools.t3code.nix";
          ProgramArguments = serviceArguments;
          EnvironmentVariables = serviceEnvironment // {
            PATH =
              builtins.replaceStrings [ "%h" "%u" ] [ config.home.homeDirectory config.home.username ]
                servicePath;
          };
          KeepAlive = true;
          ProcessType = "Background";
          RunAtLoad = true;
          WorkingDirectory = serverConfig.workingDirectory;
        };
      };
    })
  ];
}
