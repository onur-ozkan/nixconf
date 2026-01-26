{ pkgs }:
''
  if [ -z "$ZSH_VERSION" ] && [ -n "$PS1" ] && [ -z "$NIX_DEV_ZSH" ]; then
    export NIX_DEV_ZSH=1
    exec zsh -l
  fi
''
