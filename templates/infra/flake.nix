{
  description = "infra runner for Rust backend: git pull -> cargo build --release -> run";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    fenix.url = "github:nix-community/fenix";
  };

  outputs = { self, nixpkgs, fenix }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);

      appName = "test";
      binName = "test";
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          fenixPkgs = fenix.packages.${system};

          rustToolchain = fenixPkgs.combine [
            fenixPkgs.stable.rustc
            fenixPkgs.stable.cargo
            fenixPkgs.stable.clippy
            fenixPkgs.stable.rustfmt
            fenixPkgs.stable.rust-src
            fenixPkgs.stable.rust-analyzer
          ];

          rustRun = pkgs.writeShellApplication {
            name = "${appName}-run";
            runtimeInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.git
              pkgs.cacert

              rustToolchain

              pkgs.pkg-config
              pkgs.openssl

              pkgs.clang
              pkgs.lld
              pkgs.gnumake
            ];
            text = ''
              set -euo pipefail

              REPO_URL="''${REPO_URL:-https://github.com/monadimi/your-rust-repo.git}"
              BRANCH="''${BRANCH:-main}"

              APP_NAME="''${APP_NAME:-${appName}}"
              BIN_NAME="''${BIN_NAME:-${binName}}"

              APP_DIR="''${APP_DIR:-/home/monad/apps/$APP_NAME/app}"
              CACHE_DIR="''${CACHE_DIR:-/var/cache/$APP_NAME}"
              CARGO_HOME="''${CARGO_HOME:-$CACHE_DIR/cargo-home}"
              CARGO_TARGET_DIR="''${CARGO_TARGET_DIR:-$CACHE_DIR/target}"

              ENV_FILE="''${ENV_FILE:-/etc/$APP_NAME/$APP_NAME.env}"

              export CARGO_HOME
              export CARGO_TARGET_DIR

              mkdir -p "$APP_DIR" "$CACHE_DIR" "$CARGO_HOME" "$CARGO_TARGET_DIR"

              if [ ! -d "$APP_DIR/.git" ]; then
                git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
              else
                cd "$APP_DIR"
                git fetch origin "$BRANCH" --depth 1
                git reset --hard "origin/$BRANCH"
                git clean -fd
              fi

              cd "$APP_DIR"

              if [ -f "$ENV_FILE" ]; then
                set -a
                . "$ENV_FILE"
                set +a
              fi

              if [ -f "Cargo.lock" ]; then
                cargo build --release --locked
              else
                cargo build --release
              fi

              exec "$CARGO_TARGET_DIR/release/$BIN_NAME"
            '';
          };

          installSystemd = pkgs.writeShellApplication {
            name = "${appName}-install-systemd";
            runtimeInputs = [
              pkgs.bash
              pkgs.coreutils
              pkgs.systemd
              pkgs.nix
            ];
            text = ''
              set -euo pipefail

              APP_NAME="''${APP_NAME:-${appName}}"
              USER_NAME="''${USER_NAME:-monad}"
              GROUP_NAME="''${GROUP_NAME:-monad}"
              WORKDIR="''${WORKDIR:-/home/$USER_NAME/apps/$APP_NAME}"

              UNIT_PATH="/etc/systemd/system/$APP_NAME.service"
              ENV_DIR="/etc/$APP_NAME"
              ENV_FILE="$ENV_DIR/$APP_NAME.env"

              OUT_LINK="$WORKDIR/nix-$APP_NAME-runner"

              mkdir -p "$WORKDIR"
              mkdir -p "$ENV_DIR"

              if [ ! -f "$ENV_FILE" ]; then
                cat > "$ENV_FILE" <<EOF
# export-style env file (bash)
# Example:
# PORT=8080
# RUST_LOG=info
EOF
                chmod 600 "$ENV_FILE" || true
              fi

              nix build ".#${appName}-run" --out-link "$OUT_LINK"

              cat > "$UNIT_PATH" <<EOF
[Unit]
Description=$APP_NAME (Rust) - git pull, build, run
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=$USER_NAME
Group=$GROUP_NAME
WorkingDirectory=$WORKDIR
EnvironmentFile=$ENV_FILE
ExecStart=$OUT_LINK/bin/${appName}-run
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

              systemctl daemon-reload
              systemctl enable --now "$APP_NAME.service"

              echo "installed: $UNIT_PATH"
              echo "env file : $ENV_FILE"
              echo "status   : systemctl status $APP_NAME.service"
            '';
          };
        in
        {
          "${appName}-run" = rustRun;
          "${appName}-install-systemd" = installSystemd;
          default = rustRun;
        }
      );

      # CI/test harness expects this to exist
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          fenixPkgs = fenix.packages.${system};

          rustToolchain = fenixPkgs.combine [
            fenixPkgs.stable.rustc
            fenixPkgs.stable.cargo
            fenixPkgs.stable.clippy
            fenixPkgs.stable.rustfmt
            fenixPkgs.stable.rust-src
            fenixPkgs.stable.rust-analyzer
          ];
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.git
              pkgs.curl
              pkgs.cacert
              pkgs.nix
              pkgs.systemd
              rustToolchain
              pkgs.pkg-config
              pkgs.openssl
              pkgs.clang
              pkgs.lld
              pkgs.gnumake
            ];
          };
        }
      );

      apps = forAllSystems (system: {
        run = {
          type = "app";
          program = "${self.packages.${system}."${appName}-run"}/bin/${appName}-run";
        };

        install-systemd = {
          type = "app";
          program = "${self.packages.${system}."${appName}-install-systemd"}/bin/${appName}-install-systemd";
        };
      });
    };
}
