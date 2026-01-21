{
  description = "Monad devShell: dioxus";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        rustTools = with pkgs; [
          cargo
          rustc
          rustfmt
          clippy
        ];

        wasmTools = with pkgs; [
          wasm-pack
          wasm-bindgen-cli
          trunk
        ];

        dioxusTools = with pkgs; [
          dioxus-cli
        ];

        nativeDepsLinux = with pkgs; [
          pkg-config
          openssl
          zlib
          glib
          gtk3
          webkitgtk
        ];

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
      in
      {
        devShells.default = pkgs.mkShell {
          packages =
            commonTools
            ++ fmtTools
            ++ rustTools
            ++ wasmTools
            ++ dioxusTools
            ++ pkgs.lib.optionals pkgs.stdenv.isLinux nativeDepsLinux;

          RUST_BACKTRACE = "1";
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
      }
    );
}