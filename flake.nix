{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default =
          with pkgs;
          mkShell {
            buildInputs = [
              (ruby.withPackages (ps: with ps; [ bundler solargraph rspec ]))
              turso-cli
              ruby-lsp
            ] ++ lib.optionals stdenv.isDarwin [ iconv ];
          };
      });
}

