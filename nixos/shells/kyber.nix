{
  pkgs ? import <nixpkgs> {},
  resolvePath ? null,
}: let
  enableZsh = import (
    if resolvePath == null
    then ./enable-zsh.nix
    else resolvePath "nixos/shells/enable-zsh.nix"
  ) {inherit pkgs;};
in
  pkgs.mkShell {
    shellHook =
      ''
        export NIX_DEV_SHELL_NAME="kyber"
      ''
      + enableZsh;
  }
