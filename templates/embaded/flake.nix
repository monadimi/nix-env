{
  description = "Monad devShell: embaded";

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
          sh = pkgs.runCommand "check-shell" { } ''
            if ls -1 **/*.sh >/dev/null 2>&1; then
              ${pkgs.shellcheck}/bin/shellcheck -x **/*.sh
              ${pkgs.shfmt}/bin/shfmt -d **/*.sh
            fi
            touch $out
          '';
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}