{
  description = "Monad devShell: Flutter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            android_sdk.accept_license = true;
          };
        };

        localVersion = "v0.1.5";

        remoteVersionUrl =
          "https://raw.githubusercontent.com/monadimi/nix-env/main/templates/flutter/version";
        remoteFlakeUrl =
          "https://raw.githubusercontent.com/monadimi/nix-env/main/templates/flutter/flake.nix";

        updateScript = pkgs.writeShellScriptBin "flutter-flake-self-update" ''
          set -euo pipefail

          if [ "''${UPDATE:-1}" = "0" ]; then
            exit 0
          fi

          if ! command -v curl >/dev/null 2>&1; then
            exit 0
          fi

          if [ ! -f "./flake.nix" ]; then
            exit 0
          fi

          read_local_version() {
            sed -nE 's/^[[:space:]]*localVersion[[:space:]]*=[[:space:]]*"([^"]+)".*$/\1/p' ./flake.nix | head -n 1 || true
          }

          read_remote_version_file() {
            curl -fsSL --max-time 5 "${remoteVersionUrl}" 2>/dev/null \
              | tr -d "\r" \
              | head -n 1 \
              | sed -e 's/[[:space:]]*$//'
          }

          read_version_from_file() {
            sed -nE 's/^[[:space:]]*localVersion[[:space:]]*=[[:space:]]*"([^"]+)".*$/\1/p' "$1" | head -n 1 || true
          }

          local_ver="$(read_local_version)"
          if [ -z "$local_ver" ]; then
            local_ver="${localVersion}"
          fi

          remote_ver="$(read_remote_version_file)"
          if [ -z "$remote_ver" ]; then
            exit 0
          fi

          if [ "$remote_ver" = "$local_ver" ]; then
            exit 0
          fi

          tmp="$(mktemp)"
          trap 'rm -f "$tmp"' EXIT

          curl -fsSL --max-time 10 "${remoteFlakeUrl}" -o "$tmp"

          if ! grep -q 'description' "$tmp"; then
            echo "Self-update aborted: invalid flake.nix"
            exit 0
          fi

          remote_flake_ver="$(read_version_from_file "$tmp")"
          if [ -z "$remote_flake_ver" ]; then
            echo "Self-update aborted: remote flake has no localVersion field"
            exit 0
          fi

          if [ "$remote_flake_ver" != "$remote_ver" ]; then
            echo "Self-update aborted: version mismatch"
            echo "version file : $remote_ver"
            echo "remote flake : $remote_flake_ver"
            exit 0
          fi

          cp "$tmp" ./flake.nix

          rm -f "./flake.lock" || true
          rm -rf "./.zsh-nix" || true

          new_local_ver="$(read_local_version)"
          if [ -z "$new_local_ver" ]; then
            echo "Self-update warning: could not read updated localVersion from flake.nix"
          fi

          cat <<EOF

============================================================
flake.nix has been UPDATED from remote template
------------------------------------------------------------
Before update : $local_ver
After update  : ''${new_local_ver:-unknown}
Remote version: $remote_ver

flake.lock and .zsh-nix have been removed to ensure the update applies.

IMPORTANT:
This shell will now exit. Re-run:

  nix develop

============================================================

EOF

          exit 2
        '';

        zshBootstrap = pkgs.writeShellScriptBin "zsh-omz-bootstrap" ''
          set -euo pipefail

          export ZDOTDIR="''${ZDOTDIR:-$PWD/.zsh-nix}"
          export ZSH="''${ZSH:-$ZDOTDIR/oh-my-zsh}"

          mkdir -p "$ZDOTDIR"

          if [ ! -f "$ZSH/oh-my-zsh.sh" ]; then
            rm -rf "$ZSH"
            git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$ZSH"
          fi

          PLUGDIR="$ZSH/custom/plugins"
          mkdir -p "$PLUGDIR"

          if [ ! -d "$PLUGDIR/zsh-autosuggestions" ]; then
            git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
              "$PLUGDIR/zsh-autosuggestions"
          fi

          if [ ! -d "$PLUGDIR/zsh-syntax-highlighting" ]; then
            git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
              "$PLUGDIR/zsh-syntax-highlighting"
          fi

          if [ ! -f "$ZDOTDIR/.zshrc" ] || [ ! -f "$ZSH/oh-my-zsh.sh" ]; then
            cat > "$ZDOTDIR/.zshrc" <<'EOF'
export ZSH="$ZDOTDIR/oh-my-zsh"

ZSH_THEME="agnoster"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

unset CONDA_DEFAULT_ENV CONDA_PREFIX CONDA_PROMPT_MODIFIER CONDA_SHLVL
unset _CE_CONDA _CE_MAMBA MAMBA_EXE MAMBA_ROOT_PREFIX

if [ ! -f "$ZSH/oh-my-zsh.sh" ]; then
  if command -v zsh-omz-bootstrap >/dev/null 2>&1; then
    zsh-omz-bootstrap >/dev/null 2>&1 || true
  fi
fi

if [ -f "$ZSH/oh-my-zsh.sh" ]; then
  source "$ZSH/oh-my-zsh.sh"
fi

prompt_context() {
  prompt_segment blue default "monad"
}
EOF
          fi
        '';

        flutter = pkgs.flutter;
        jdk = pkgs.jdk17;

        android = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ "34" "33" ];
          buildToolsVersions = [ "34.0.0" "33.0.2" ];
          abiVersions = [ "arm64-v8a" "armeabi-v7a" "x86_64" ];
          includeEmulator = false;
          includeSystemImages = false;
        };

        androidSdk = android.androidsdk;
        gradle = pkgs.gradle;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.zsh
            pkgs.git
            pkgs.curl
            pkgs.cacert

            flutter
            jdk
            androidSdk
            pkgs.android-tools
            gradle

            pkgs.unzip
            pkgs.zip
            pkgs.which
            pkgs.gnused
            pkgs.gawk
            pkgs.jq
            pkgs.python3

            updateScript
            zshBootstrap
          ];

          shellHook = ''
            set -e

            export NIX_CONFIG="experimental-features = nix-command flakes"

            if ! flutter-flake-self-update; then
              exit 1
            fi

            unset CONDA_DEFAULT_ENV CONDA_PREFIX CONDA_PROMPT_MODIFIER CONDA_SHLVL
            unset _CE_CONDA _CE_MAMBA MAMBA_EXE MAMBA_ROOT_PREFIX

            export JAVA_HOME="${jdk}"
            export ANDROID_HOME="${androidSdk}/libexec/android-sdk"
            export ANDROID_SDK_ROOT="$ANDROID_HOME"

            export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/tools/bin:$PATH"

            export ZDOTDIR="$PWD/.zsh-nix"
            export ZSH="$ZDOTDIR/oh-my-zsh"

            zsh-omz-bootstrap

            if [ ! -f "$ZSH/oh-my-zsh.sh" ]; then
              echo "oh-my-zsh install failed: missing $ZSH/oh-my-zsh.sh"
              echo "Try: rm -rf .zsh-nix && nix develop"
              exit 1
            fi

            if [ "''${_MONAD_NIX_ZSH_STARTED:-0}" != "1" ]; then
              export _MONAD_NIX_ZSH_STARTED=1
              exec ${pkgs.zsh}/bin/zsh
            fi
          '';
        };

        apps.update-flake = {
          type = "app";
          program = "${updateScript}/bin/flutter-flake-self-update";
        };

        apps.bootstrap-zsh = {
          type = "app";
          program = "${zshBootstrap}/bin/zsh-omz-bootstrap";
        };

        localVersion = localVersion;
      });
}
