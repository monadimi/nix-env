{
  description = "Monad devShell: base";

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
          wget
          unzip
          zip
          jq
          gnused
          gawk
          which
          tree
          ripgrep
          fd
        ];

        fmtTools = with pkgs; [
          nixfmt-rfc-style
          deadnix
          statix
          shfmt
          shellcheck
          nodePackages.prettier
        ];

        extraTools = with pkgs; [ ];

      in
      {
        devShells.default = pkgs.mkShell {
          packages = commonTools ++ fmtTools ++ extraTools;
          shellHook = ''
            echo "Monad devShell (base) (${rev})"
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
