{
  description = "Monad devShell: infra";

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

        infraTools = with pkgs; [
          terraform
          opentofu
          ansible
          kubectl
          kubernetes-helm
          kustomize
          sops
          age
          yq-go
          awscli2
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
          packages = commonTools ++ fmtTools ++ infraTools;
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