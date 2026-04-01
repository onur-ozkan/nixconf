{ pkgs ? import <nixpkgs> {} }:

let
  enableZsh = import ./enable-zsh.nix { inherit pkgs; };

  astyle31 = pkgs.astyle.overrideAttrs (old: {
    version = "3.1";

    src = pkgs.fetchurl {
      url = "https://downloads.sourceforge.net/project/astyle/astyle/astyle%203.1/astyle_3.1_linux.tar.gz";
      hash = "sha256-y8xM+ZYpRTS7VvAl1vGZ6/3oGqTCccy9XuHBoxknRdc=";
    };

    cmakeFlags = (old.cmakeFlags or []) ++ [
      "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    ];

    installPhase = ''
      runHook preInstall
      install -Dm755 astyle $out/bin/astyle
      runHook postInstall
    '';
  });

  opencvGui = pkgs.opencv.override {
    enableGtk3 = true;
  };
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
    astyle31
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    ffmpeg_6
    fontconfig
    glib
    gtk3
    libglvnd
    libxkbcommon
    llvmPackages.libclang
    llvmPackages.libcxx
    mesa
    mpv
    nodejs
    opencvGui
    qgroundcontrol
    socat
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
    pkgs.gtk3
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
