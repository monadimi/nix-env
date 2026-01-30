{
  description = "Monad devShell: Web";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        localVersion = "v0.1.3";

        remoteVersionUrl =
          "https://raw.githubusercontent.com/monadimi/nix-env/main/templates/web/version";
        remoteFlakeUrl =
          "https://raw.githubusercontent.com/monadimi/nix-env/main/templates/web/flake.nix";

        updateScript = pkgs.writeShellScriptBin "web-flake-self-update" ''
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

IMPORTANT:
This shell will now exit. Re-run:

  nix develop

============================================================

EOF

          exit 2
        '';

        node = pkgs.nodejs_20;

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

# If oh-my-zsh is missing at shell startup, try bootstrap once.
if [ ! -f "$ZSH/oh-my-zsh.sh" ]; then
  if command -v zsh-omz-bootstrap >/dev/null 2>&1; then
    zsh-omz-bootstrap >/dev/null 2>&1 || true
  fi
fi

# Only source if it exists.
if [ -f "$ZSH/oh-my-zsh.sh" ]; then
  source "$ZSH/oh-my-zsh.sh"
fi

prompt_context() {
  prompt_segment blue default "monad"
}
EOF
          fi
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.zsh
            pkgs.git
            pkgs.curl

            node
            pkgs.corepack
            pkgs.jq
            pkgs.python3
            pkgs.pkg-config
            pkgs.gcc
            pkgs.gnumake
            pkgs.cacert

            updateScript
            zshBootstrap
          ];

          shellHook = ''
            set -e

            export NIX_CONFIG="experimental-features = nix-command flakes"

            if command -v corepack >/dev/null 2>&1; then
              corepack enable >/dev/null 2>&1 || true
            fi

            if ! web-flake-self-update; then
              exit 1
            fi

            export ZDOTDIR="$PWD/.zsh-nix"
            export ZSH="$ZDOTDIR/oh-my-zsh"

            zsh-omz-bootstrap

            # Only exec into zsh if oh-my-zsh entrypoint exists (prevents .zshrc source error).
            if [ ! -f "$ZSH/oh-my-zsh.sh" ]; then
              echo "oh-my-zsh install failed: missing $ZSH/oh-my-zsh.sh"
              echo "Try: rm -rf .zsh-nix && nix develop"
              exit 1
            fi

            if [ "''${_MONAD_NIX_ZSH_STARTED:-0}" != "1" ]; then
              export _MONAD_NIX_ZSH_STARTED=1
              exec ${pkgs.zsh}/bin/zsh -l
            fi
          '';
        };

        apps.update-flake = {
          type = "app";
          program = "${updateScript}/bin/web-flake-self-update";
        };

        apps.bootstrap-zsh = {
          type = "app";
          program = "${zshBootstrap}/bin/zsh-omz-bootstrap";
        };

        localVersion = localVersion;
      });
}
