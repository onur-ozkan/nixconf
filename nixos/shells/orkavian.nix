{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    clang
    cmake
    pkg-config
    rustup
  ];

  buildInputs = with pkgs; [
    xorg.libX11
    xorg.libXcursor
    xorg.libxcb
    xorg.libXi
    libxkbcommon
    vulkan-loader
    mesa
    libglvnd
    ffmpeg_6
    fontconfig
    llvmPackages.libclang
    llvmPackages.libcxx
    opencv
    python3
  ];

  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.libxkbcommon
    pkgs.xorg.libX11
    pkgs.xorg.libXcursor
    pkgs.xorg.libxcb
    pkgs.xorg.libXi
    pkgs.vulkan-loader
    pkgs.mesa
    pkgs.libglvnd
  ];

  shellHook = ''
    export LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib"
    alias make='make HOSTCC=gcc'
  '';
}
