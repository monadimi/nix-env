{
  description = "Monad devShell: react";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        node = pkgs.nodejs_20;

        commonTools = with pkgs; [
          git
          curl
          jq
          ripgrep
          fd
        ];

        webTools = with pkgs; [
          node
          nodePackages.pnpm
          yarn
          nodePackages.prettier
          nodePackages.eslint
          nodePackages.typescript
        ];

        fmtTools = with pkgs; [
          nixfmt-rfc-style
          deadnix
          statix
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          packages = commonTools ++ fmtTools ++ webTools;
          shellHook = ''
            export NODE_ENV=development
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
      }
    );
}