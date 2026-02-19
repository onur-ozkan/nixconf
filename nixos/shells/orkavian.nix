{ pkgs ? import <nixpkgs> {} }:

let
  enableZsh = import ./enable-zsh.nix { inherit pkgs; };
in

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    clang
    cmake
    pkg-config
    rustup
    wasm-pack
  ];

  buildInputs = with pkgs; [
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    ffmpeg_6
    fontconfig
    glib
    libglvnd
    libxkbcommon
    llvmPackages.libclang
    llvmPackages.libcxx
    mesa
    mpv
    nodejs
    opencv
    qgroundcontrol
    stdenv.cc.cc.lib
    vlc
    vulkan-loader
    xorg.libX11
    xorg.libxcb
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
    zlib

    (python310.withPackages (ps: with ps; [
      pip
      setuptools
      wheel
    ]))
  ];

  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.cudaPackages.cudatoolkit
    pkgs.cudaPackages.cudnn
    pkgs.glib
    pkgs.libglvnd
    pkgs.libxkbcommon
    pkgs.mesa
    pkgs.stdenv.cc.cc.lib
    pkgs.vulkan-loader
    pkgs.xorg.libX11
    pkgs.xorg.libxcb
    pkgs.xorg.libXcursor
    pkgs.xorg.libXi
    pkgs.xorg.libXrandr
    pkgs.zlib
  ];

  shellHook = ''
    export NIX_DEV_SHELL_NAME="orkavian"

    export LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib"
    export CUDA_PATH="${pkgs.cudaPackages.cudatoolkit}"

    if [ -d /run/opengl-driver/lib ]; then
      export LD_LIBRARY_PATH="/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    fi
  '' + enableZsh;
}
