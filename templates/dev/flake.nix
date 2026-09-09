{
  description = "Per-project devShell — activated by direnv via .envrc";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: let
    forAllSystems = nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux"];
  in {
    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          # Trim to what this project needs
          nodejs
          pnpm
          go
          python3
          uv
          gcc
          gnumake
          pkg-config
        ];
      };
    });
  };
}
