{pkgs}: ''
  host_shell=$(getent passwd "$(id -un)" | cut -d: -f7)
  if [ -n "$host_shell" ] && [ "''${SHELL-}" != "$host_shell" ]; then
    export SHELL="$host_shell"
    exec "$host_shell"
  fi
''
