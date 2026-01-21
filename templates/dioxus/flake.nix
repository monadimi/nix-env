{
  description = "Monad devShell: dioxus";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        rev = self.shortRev or self.rev or "dirty";

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
        ];

        baseTools = with pkgs; [
          cargo
          rustc
          rustfmt
          llvmPackages.lld
          clippy
          wasm-pack
          wasm-bindgen-cli
          trunk
          dioxus-cli
        ];

        linuxDeps = with pkgs; [
          pkg-config
          openssl
          zlib
          glib
          gtk3
          webkitgtk
        ];
      in {
        devShells.default = pkgs.mkShell {
          packages =
            commonTools
            ++ fmtTools
            ++ baseTools
            ++ pkgs.lib.optionals pkgs.stdenv.isLinux linuxDeps;

          RUST_BACKTRACE = "1";

          shellHook = ''
            echo "Monad devShell (dioxus) (${rev})"
          '';
        };

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
