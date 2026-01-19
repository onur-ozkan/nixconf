{ pkgs ? import <nixpkgs> {} }:

let
  inherit (pkgs) lib writers;
  inherit (pkgs.llvmPackages) clang;

  # When --target is used, skip clang wrapper.
  wrappedClang = writers.writeBashBin "clang" ''
    target_specified=
    for arg in "$@"; do
      case "$arg" in
        "--target"*)
          target_specified=1
          ;;
      esac
    done

    if [[ -n $target_specified ]]; then
      exec ${lib.getExe clang.cc} "$@"
    else
      exec ${lib.getExe clang} "$@"
    fi
  '';
in

pkgs.mkShell {
  packages = with pkgs; [
    bison
    elfutils
    flex
    gcc
    glibc.dev
    wrappedClang
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
  '';
}
