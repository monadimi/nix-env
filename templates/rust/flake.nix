{
  description = "Monad devShell: rust";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        commonTools = with pkgs; [
          git
          curl
          jq
          ripgrep
          fd
        ];

        rustTools = with pkgs; [
          cargo
          rustc
          rustfmt
          clippy
          pkg-config
          openssl
        ];

        fmtTools = with pkgs; [
          nixfmt-rfc-style
          deadnix
          statix
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          packages = commonTools ++ fmtTools ++ rustTools;
          RUST_BACKTRACE = "1";
        };

        checks = {
          nixfmt = pkgs.runCommand "check-nixfmt" { } ''
            ${pkgs.nixfmt-rfc-style}/bin/nixfmt --check ${./.}
            touch $out
          '';
          deadnix = pkgs.runCommand "check-deadnix" { } ''
            ${pkgs.deadnix}/bin/deadnix ${./.}
            touch $out
          '';
          statix = pkgs.runCommand "check-statix" { } ''
            ${pkgs.statix}/bin/statix check ${./.}
            touch $out
          '';
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}