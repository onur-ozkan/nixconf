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
    python3
    rustup
    qemu
  ];

  nativeBuildInputs = with pkgs; [
    rust-bindgen
  ];

  shellHook = ''
    export BINDGEN_EXTRA_CLANG_ARGS="-Wno-unused-command-line-argument"
    alias make='make HOSTCC=gcc'
  '';
}