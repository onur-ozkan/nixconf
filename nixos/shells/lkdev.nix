{ pkgs ? import <nixpkgs> {} }:

let
  aarch64Toolchain = pkgs.pkgsCross.aarch64-multiplatform.buildPackages;
  enableZsh = import ./enable-zsh.nix { inherit pkgs; };
  inherit (pkgs.llvmPackages) clang;
  inherit (pkgs) lib writers;

  # When --target is used, skip clang wrapper.
  wrappedClang = writers.writeBashBin "clang" ''
    target_specified=
    print_builtin_include=
    for arg in "$@"; do
      case "$arg" in
        "--target"*)
          target_specified=1
          ;;
        # Kernel uses this to locate builtin headers like arm_neon.h.
        "-print-file-name=include")
          print_builtin_include=1
          ;;
      esac
    done

    if [[ -n $target_specified || -n $print_builtin_include ]]; then
      exec ${lib.getExe clang.cc} "$@"
    else
      exec ${lib.getExe clang} "$@"
    fi
  '';
in

pkgs.mkShell {
  packages = with pkgs; [
    aarch64Toolchain.binutils
    aarch64Toolchain.gcc
    bison
    elfutils
    flex
    gcc
    glibc.dev
    gnutls.dev
    llvmPackages.lld
    llvmPackages.llvm
    openssl.dev
    picocom
    qemu
    rustup
    swig
    wrappedClang

    (python3.withPackages (ps: with ps; [
      setuptools
    ]))
  ];

  nativeBuildInputs = with pkgs; [
    rust-bindgen
  ];

  shellHook = ''
    export NIX_DEV_SHELL_NAME="lkdev"
    export BINDGEN_EXTRA_CLANG_ARGS="-Wno-unused-command-line-argument"
  '' + enableZsh;
}
