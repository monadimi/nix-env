{
  description = "Monad devShell: embaded";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils }:
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

        buildTools = with pkgs; [
          cmake
          ninja
          gnumake
          pkg-config
          python3
          python3Packages.pip
        ];

        embeddedTools = with pkgs; [
          gcc-arm-embedded
          openocd
          picocom
          minicom
          esptool
        ];

        fmtTools = with pkgs; [
          nixfmt-rfc-style
          deadnix
          statix
          shfmt
          shellcheck
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          packages = commonTools ++ fmtTools ++ buildTools ++ embeddedTools;
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

          sh = pkgs.runCommand "check-shell" { } ''
            set -euo pipefail
            if find ${./.} -type f -name "*.sh" -print -quit | grep -q .; then
              ${pkgs.shellcheck}/bin/shellcheck -x $(find ${./.} -type f -name "*.sh")
              ${pkgs.shfmt}/bin/shfmt -d $(find ${./.} -type f -name "*.sh")
            fi
            touch $out
          '';
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}