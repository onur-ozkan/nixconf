{
  pkgs ? import <nixpkgs> {},
  resolvePath ? null,
}: let
  useHostShell = import (
    if resolvePath == null
    then ./use-host-shell.nix
    else resolvePath "nixos/shells/use-host-shell.nix"
  ) {inherit pkgs;};

  enterHostShell = pkgs.writeShellScript "kyber-enter" (useHostShell + ''
    exec bash
  '');

  pythonPackages = ps:
    with ps; [
      jinja2
    ];
  python = pkgs.python3.withPackages pythonPackages;
  pythonPath = pkgs.python3.pkgs.makePythonPath (pythonPackages pkgs.python3.pkgs);

  # Kyber build scripts overwrite PKG_CONFIG_PATH with OUT_DIR paths.
  # exec the real pkg-config from the store as /usr/bin/pkg-config
  # inside the FHS env is this wrapper itself, which would recurse.
  pkgConfigPath = "/usr/lib/pkgconfig:/usr/share/pkgconfig";
  pkgConfigWrapper = pkgs.writeShellScriptBin "pkg-config" ''
    export PKG_CONFIG_PATH="${pkgConfigPath}''${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export PKG_CONFIG_LIBDIR="${pkgConfigPath}''${PKG_CONFIG_LIBDIR:+:$PKG_CONFIG_LIBDIR}"
    exec ${pkgs.pkg-config}/bin/pkg-config "$@"
  '';

  targetPackages = p:
    (with p; [
      alsa-lib
      autoconf
      automake
      bison
      cargo
      cargo-c
      cmake
      flex
      gcc
      gettext
      git
      gnumake
      libdrm
      libinput
      libopus
      libpulseaudio
      libtool
      libx11
      libxcb
      libxcursor
      libxext
      libxi
      libxkbcommon
      libxrandr
      libxrender
      llvmPackages.libclang
      lua5_4
      m4
      meson
      nasm
      ninja
      pipewire
      pkg-config
      rustc
      systemd
      wayland
      wget
      xorgproto
      zlib
    ])
    ++ [python pkgConfigWrapper];
in
  (pkgs.buildFHSEnv {
    name = "kyber";
    targetPkgs = targetPackages;
    extraOutputsToInstall = ["dev"];
    runScript = "${enterHostShell}";

    profile = ''
      export NIX_DEV_SHELL_NAME="kyber"

      export BUILDCC=gcc
      export LIBCLANG_PATH="${pkgs.llvmPackages.libclang.lib}/lib"
      export PKG_CONFIG="${pkgConfigWrapper}/bin/pkg-config"
      export PKG_CONFIG_PATH="${pkgConfigPath}"
      export PKG_CONFIG_LIBDIR="${pkgConfigPath}"
      export PYTHONPATH="${pythonPath}''${PYTHONPATH:+:$PYTHONPATH}"
      export BINDGEN_EXTRA_CLANG_ARGS="-isystem /usr/include"
      export BINDGEN_EXTRA_CLANG_ARGS_x86_64_unknown_linux_gnu="-isystem /usr/include"
      export PATH="${pkgConfigWrapper}/bin:$PATH"
      unset AS
    '';
  })
  .env
