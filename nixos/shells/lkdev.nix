{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    bison
    elfutils
    flex
    gcc
    glibc.dev
    llvmPackages.clang-unwrapped
    llvmPackages.lld
    llvmPackages.llvm
    openssl.dev
    pkg-config
    python3
    qemu
  ];

  nativeBuildInputs = with pkgs; [
    rustc
    cargo
    rust-bindgen
    rustfmt
    clippy
  ];

  RUST_LIB_SRC = pkgs.rustPlatform.rustLibSrc;

  shellHook = ''
    export RUST_SRC_PATH="$RUST_LIB_SRC"
    export BINDGEN_EXTRA_CLANG_ARGS="-Wno-unused-command-line-argument"
    alias make='make HOSTCC=gcc'
  '';
}