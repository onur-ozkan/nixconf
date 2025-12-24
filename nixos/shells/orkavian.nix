{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    python3
  ];

  nativeBuildInputs = with pkgs; [
    rustc
    cargo
    rustfmt
    clippy
  ];

  RUST_LIB_SRC = pkgs.rustPlatform.rustLibSrc;

  shellHook = ''
    export RUST_SRC_PATH="$RUST_LIB_SRC"
    alias make='make HOSTCC=gcc'
  '';
}