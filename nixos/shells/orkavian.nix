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
    xorg.libXrandr
    libxkbcommon
    vulkan-loader
    mesa
    libglvnd
    ffmpeg_6
    fontconfig
    llvmPackages.libclang
    llvmPackages.libcxx
    opencv
    zlib
    stdenv.cc.cc.lib
    glib
    qgroundcontrol

    (python310.withPackages (ps: with ps; [
      pip
      setuptools
      wheel
    ]))
  ];

  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
    pkgs.libxkbcommon
    pkgs.xorg.libX11
    pkgs.xorg.libXcursor
    pkgs.xorg.libxcb
    pkgs.xorg.libXi
    pkgs.xorg.libXrandr
    pkgs.vulkan-loader
    pkgs.mesa
    pkgs.libglvnd
    pkgs.zlib
    pkgs.stdenv.cc.cc.lib
    pkgs.glib
  ];

  shellHook = ''
    export LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib"
  '';
}
