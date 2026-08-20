# t3-code-nix

Nix packages and Home Manager modules for the stable and nightly
[T3 Code](https://t3.codes) desktop client and headless server.

The repository keeps client and server versions together. Each channel has an
official prebuilt variant and a source variant built with Nixpkgs toolchains.
Auto-update is disabled because the flake owns upgrades.

## Platform support

| Package variant | aarch64-darwin | aarch64-linux | x86_64-linux |
| --- | --- | --- | --- |
| Prebuilt client | Yes | No | Yes |
| Source client | Yes | Yes | Yes |
| Prebuilt server | Yes | Yes | Yes |
| Source server | Yes | Yes | Yes |

Upstream does not publish an ARM Linux desktop artifact. Use
`packageVariant = "source"` on `aarch64-linux`. Intel macOS is intentionally
outside the flake's declared systems.

## Add the flake

```nix
{
  inputs.t3-code-nix.url = "github:LisaScheers/t3-code-nix";
}
```

### Direct packages

Stable prebuilt client and server:

```sh
nix run github:LisaScheers/t3-code-nix#t3code
nix run github:LisaScheers/t3-code-nix#t3code-server -- serve
```

Nightly source client and server:

```sh
nix run github:LisaScheers/t3-code-nix#t3code-nightly-source
nix run github:LisaScheers/t3-code-nix#t3code-server-nightly-source -- serve
```

The package names are:

| Client | Server | Channel and variant |
| --- | --- | --- |
| `t3code` | `t3code-server` | Stable prebuilt |
| `t3code-source` | `t3code-server-source` | Stable source |
| `t3code-nightly` | `t3code-server-nightly` | Nightly prebuilt |
| `t3code-nightly-source` | `t3code-server-nightly-source` | Nightly source |

### Overlay

```nix
{
  nixpkgs.overlays = [ inputs.t3-code-nix.overlays.default ];
  environment.systemPackages = [ pkgs.t3code ];
}
```

The overlay exports the same names as `packages.<system>`.

## Home Manager

Import the combined module once:

```nix
{
  imports = [ inputs.t3-code-nix.homeModules.t3code ];
}
```

Install the stable prebuilt desktop client:

```nix
{
  programs.t3code = {
    enable = true;
    channel = "stable";
    packageVariant = "prebuilt";
  };
}
```

Install the nightly source client:

```nix
{
  programs.t3code = {
    enable = true;
    channel = "nightly";
    packageVariant = "source";
  };
}
```

The module extends Home Manager's T3 Code settings module, so options such as
`userSettings`, `keybindings`, and `clientSettings` remain available. A direct
`programs.t3code.package` override takes precedence over `channel` and
`packageVariant`.

Run the server as a Linux systemd user service or macOS launch agent:

```nix
{
  services.t3code = {
    enable = true;
    channel = "stable";
    packageVariant = "prebuilt";
    host = "127.0.0.1";
    port = 3773;
    providerPackages = [
      pkgs.codex
      pkgs.claude-code
    ];
  };
}
```

Server options also include `package`, `dataDirectory`, `workingDirectory`,
`environment`, and `extraArguments`. The default data directory is
`$XDG_DATA_HOME/t3code`. Desktop-managed state uses T3 Code's normal `~/.t3`
location.

Provider CLIs are discovered through `PATH`. Add declaratively installed
provider packages to `services.t3code.providerPackages`, or supply a package
override that wraps the required tools.

When client and server are enabled in the same Home Manager configuration,
evaluation rejects different versions. Prebuilt and source packages can be
mixed when their release versions match.

The server binds to `127.0.0.1` by default. Setting `host = "0.0.0.0"` exposes
it to the network and should be paired with appropriate access controls.

## Release channels and source builds

`stable` follows the npm `latest` dist-tag. `nightly` follows the npm `nightly`
dist-tag. The updater accepts a release only when the exact npm version and
GitHub release tag match and all expected desktop artifacts exist.

Prebuilt clients repackage the immutable GitHub release assets. Prebuilt
servers install the exact `t3@version` npm package with a committed lock file.
Source packages fetch the matching Git tag and use pinned pnpm, Cargo, Node,
and Electron inputs from Nixpkgs. Client and server selectors share the
expensive source build and resource-monitor derivation.

Source-built macOS applications are unsigned. Source builds also omit
upstream's private release credentials and production cloud configuration, so
T3 Connect may be unavailable until upstream documents reusable public values.

## Updates

GitHub Actions checks both channels at minute 17 of every hour. Upstream checks
nightly releases every three hours, so a complete release normally appears
here within one additional hour. GitHub schedules are best effort.

Run the same updater locally:

```sh
nix develop -c ./scripts/update-releases stable
nix develop -c ./scripts/update-releases nightly
nix develop -c ./scripts/update-releases all
```

An incomplete upstream release leaves the repository unchanged. A successful
update refreshes the source, pnpm, Cargo, npm, and desktop artifact hashes. CI
opens one long-lived pull request per channel and enables squash auto-merge
after all package and module checks pass.

The workflow expects `T3CODE_UPDATE_TOKEN`: a GitHub App installation token or
fine-grained bot token with repository contents and pull request write access.

The weekly flake-input workflow remains separate from T3 Code release updates.
