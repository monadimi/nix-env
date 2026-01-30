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

        localVersion = "v0.1.1";

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

          local_ver="${localVersion}"
          remote_ver="$(
            curl -fsSL --max-time 5 "${remoteVersionUrl}" 2>/dev/null \
              | tr -d "\r" \
              | head -n 1 \
              | sed -e 's/[[:space:]]*$//'
          )"

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

          cp "$tmp" ./flake.nix

          cat <<EOF

============================================================
flake.nix has been UPDATED from remote template
------------------------------------------------------------
Local version : $local_ver
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

          # Repair incomplete clone: require the real entrypoint file
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

          # If .zshrc missing OR oh-my-zsh entrypoint missing, rewrite .zshrc
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
