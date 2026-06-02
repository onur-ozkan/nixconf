{pkgs}: ''
  if [ -z "''${NIX_HOST_SHELL_ENTERED-}" ]; then
    export NIX_HOST_SHELL_ENTERED=1
    SHELL=$(getent passwd "$(id -un)" | cut -d: -f7)
    export SHELL
    exec "$SHELL"
  fi
''
