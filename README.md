NixOS bootstrapper that sets up my development environment on top of
[dwm-enhanced](https://github.com/onur-ozkan/dwm-enhanced).

<img width="1921" height="1201" alt="_2025-12-11_16-06" src="https://github.com/user-attachments/assets/2540f455-89b7-4cac-9217-d575ac642b8e" />

## Bootstrap

1. Replace the placeholder `nixos/hosts/nimda/hardware-configuration.nix` with
the actual `hardware-configuration.nix` of the system. 

2. Adjust host/user details in `nixos/hosts/nimda/configuration.nix` and `nixos/home/default.nix`.

3. (optional) Review the patches in `nixos/patches` and modify or remove any you don't
need (if you remove any, you may need to update dwmblocksPatch in `nixos/modules/packages.nix`).

4. Run:

```
# The default hostname is "nimda".
sudo nixos-rebuild switch --flake .#${hostname}
```

## Development Shells

To access development environment shells (like `lkdev`) from anywhere
on your system add this flake to your local registry.

1. Register nixconf:

```
nix registry add nixconf $path_to_nixconf
```

2. Launch a shell (run from any directory):

```
dsh $shell_name
```

## Utility Scripts

Scripts under `.local/bin` that I use for my own workflow:

- `aodev`: Lets me choose a PipeWire output device from `dmenu` and sets it as default.
- `cfreq`: Watches and prints live CPU MHz values from `/proc/cpuinfo`.
- `next_wallpaper`: Rotates to the next wallpaper in `~/.backgrounds`.
- `remote-shell`: Syncs the current local project to a configured remote host and opens an SSH shell there.
- `www_search`: Opens a URL directly (if input looks like a domain) or searches DuckDuckGo via `dmenu` input.
- `statusbar/*`: Various scripts used for `dwmblocks` status modules.
