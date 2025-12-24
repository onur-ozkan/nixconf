{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    clang
    cmake
    pkg-config
    rustup
  ];

  buildInputs = with pkgs; [
    ffmpeg_6
    fontconfig
    llvmPackages.libclang
    llvmPackages.libcxx
    opencv
    python3
  ];

  RUST_LIB_SRC = pkgs.rustPlatform.rustLibSrc;

  shellHook = ''
  	export LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib"
    export RUST_SRC_PATH="$RUST_LIB_SRC"

    alias make='make HOSTCC=gcc'
  '';
}
