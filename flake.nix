{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};
      neovim-test = pkgs.neovim.override {
        configure = {
          packages.test = with pkgs.vimPlugins; {
            start = [plenary-nvim];
          };
        };
      };
    in {
      devShells = {
        default = with pkgs;
          mkShell {
            packages = [
              just
              alejandra
            ];
          };
        test = with pkgs;
          mkShell {
            packages = [
              neovim-test
              just
            ];
          };
      };
    });
}
