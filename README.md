NixOS bootstrapper that sets up my development environment on top of
[dwm-enhanced](https://github.com/onur-ozkan/dwm-enhanced).

<img width="1921" height="1201" alt="_2025-12-11_16-06" src="https://github.com/user-attachments/assets/2540f455-89b7-4cac-9217-d575ac642b8e" />

## Bootstrap

1. Use `override/` directory for any local-only changes.

	The path must mirror the repository path exactly e.g.:

	- `override/nixos/hosts/nimda/hardware-configuration.nix`
	- `override/nixos/hosts/nimda/configuration.nix`
	- `override/nixos/home/default.nix`
	- `override/.local/bin/remote-shell`
	- `override/.config/remote-shell/config.toml`

	If a matching path exists under `override/`, Nix will use that path instead of the tracked file.

2. Put your system-specific `hardware-configuration.nix` at `override/nixos/hosts/nimda/hardware-configuration.nix`.

3. (optional) Review the patches in `nixos/patches` and modify or remove any you don't
need (if you remove any, you may need to update dwmblocksPatch in `nixos/modules/packages.nix`).

4. Run the flake as a local path so ignored files in `override/` are visible:

```
# The default hostname is "nimda".
sudo nixos-rebuild switch --flake "path:$PWD#${hostname}"
```

## Development Shells

To access development environment shells (like `lkdev`) from anywhere
on your system add this flake to your local registry.

1. Register nixconf:

```
nix registry add nixconf "path:$path_to_nixconf"
```

2. Launch a shell (run from any directory):

```
dsh $shell_name
```

## Utility Scripts

Scripts under `.local/bin` that I use for my own workflow:

- `aodev`: Lets me choose a PipeWire output device from `dmenu` and sets it as default.
- `cfreq`: Watches and prints live CPU MHz values from `/proc/cpuinfo`.
- `next-bg`: Rotates to the next wallpaper in `~/.backgrounds`.
- `remote-shell`: Syncs the current local project to a configured remote host and opens an SSH shell there.
- `www`: Opens a URL directly (if input looks like a domain) or searches DuckDuckGo via `dmenu` input.
- `statusbar/*`: Various scripts used for `dwmblocks` status modules.
