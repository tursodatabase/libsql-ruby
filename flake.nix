{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    ruby-nix.url = "github:inscapist/ruby-nix";
    bundix = {
      url = "github:inscapist/bundix/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
  };
  outputs = { self, nixpkgs, flake-utils, ruby-nix, bundix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ ruby-nix.overlays.ruby ];
        };
        rubyNix = ruby-nix.lib pkgs;

        inherit (rubyNix {
          gemset = if builtins.pathExists ./gemset.nix then import ./gemset.nix else { };
          name = "ruby-env";
        }) env ruby;
      in
      {
        devShells.default =
          with pkgs;
          mkShell {
            buildInputs = [
              bundix.packages.${system}.default
              turso-cli
              rubyPackages.solargraph

              env
              ruby
            ] ++ lib.optionals stdenv.isDarwin [ iconv ];
          };
      });
}


