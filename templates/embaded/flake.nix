{description = "Monad devShell: embaded";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        rev = self.shortRev or self.rev or "dirty";

        localVersion = "v0.1.1";

        remoteVersionUrl =
          "https://raw.githubusercontent.com/monadimi/nix-env/main/templates/embaded/version";
        remoteFlakeUrl =
          "https://raw.githubusercontent.com/monadimi/nix-env/main/templates/embaded/flake.nix";

        updateScript = pkgs.writeShellScriptBin "embaded-flake-self-update" ''
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
            curl -fsSL --max-time 5 "https://raw.githubusercontent.com/monadimi/nix-env/main/templates/embaded/version" 2>/dev/null               | tr -d "\r"               | head -n 1               | sed -e 's/[[:space:]]*$//'
          }

          read_version_from_file() {
            sed -nE 's/^[[:space:]]*localVersion[[:space:]]*=[[:space:]]*"([^"]+)".*$/\1/p' "$1" | head -n 1 || true
          }

          local_ver="$(read_local_version)"
          if [ -z "$local_ver" ]; then
            local_ver="v0.1.1"
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

          curl -fsSL --max-time 10 "https://raw.githubusercontent.com/monadimi/nix-env/main/templates/embaded/flake.nix" -o "$tmp"

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
            git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions               "$PLUGDIR/zsh-autosuggestions"
          fi

          if [ ! -d "$PLUGDIR/zsh-syntax-highlighting" ]; then
            git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting               "$PLUGDIR/zsh-syntax-highlighting"
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

source "$ZSH/oh-my-zsh.sh"

prompt_context() {
  prompt_segment blue default "monad"
}
EOF
          fi
        '';

        commonTools = with pkgs; [
          git
          curl
          jq
          ripgrep
          fd
        ];

        fmtTools = with pkgs; [
          nixfmt-rfc-style
          deadnix
          statix
          shfmt
          shellcheck
        ];

        extraTools = with pkgs; [
          cmake
          ninja
          gnumake
          pkg-config
          python3
          python3Packages.pip
          gcc-arm-embedded
          openocd
          picocom
          minicom
          esptool
        ];
      in {
        devShells.default = pkgs.mkShell {
          packages = commonTools ++ fmtTools ++ extraTools ++ [ pkgs.zsh updateScript zshBootstrap ];
          shellHook = ''
            set -e
            export NIX_CONFIG="experimental-features = nix-command flakes"
            if ! embaded-flake-self-update; then
              echo
              echo "NOTICE: flake.nix was updated during shell entry."
              echo "This shell will now exit. Re-run:"
              echo
              echo "  nix develop"
              echo
              exit 1
            fi
            export ZDOTDIR="$PWD/.zsh-nix"
            zsh-omz-bootstrap
                        echo "Monad devShell (embaded) (${rev})"
            if [ "''${_MONAD_NIX_ZSH_STARTED:-0}" != "1" ]; then
              export _MONAD_NIX_ZSH_STARTED=1
              exec ${pkgs.zsh}/bin/zsh -l
            fi
          '';

        };
        apps.update-flake = {
          type = "app";
          program = "${updateScript}/bin/embaded-flake-self-update";
        };

        apps.bootstrap-zsh = {
          type = "app";
          program = "${zshBootstrap}/bin/zsh-omz-bootstrap";
        };

        localVersion = localVersion;

        checks = {
          nixfmt = pkgs.runCommand "check-nixfmt" { } ''
            set -euo pipefail
            find ${./.} -type f -name "*.nix" -print0 | xargs -0 ${pkgs.nixfmt-rfc-style}/bin/nixfmt --check
            touch $out
          '';

          deadnix = pkgs.runCommand "check-deadnix" { } ''
            set -euo pipefail
            ${pkgs.deadnix}/bin/deadnix ${./.}
            touch $out
          '';

          statix = pkgs.runCommand "check-statix" { } ''
            set -euo pipefail
            ${pkgs.statix}/bin/statix check ${./.}
            touch $out
          '';
        };

        formatter = pkgs.nixfmt-rfc-style;
      });
}
