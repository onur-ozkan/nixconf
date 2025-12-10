NixOS bootstrapper that sets up my personal desktop environment.

## Layout

- `flake.nix`: entry point that exposes the `nimda` host, pulls in personal suckless forks, and integrates Home Manager.
- `nixos/hosts/nimda`: host-specific system configuration plus hardware stub (replace with your own).
- `nixos/modules/packages.nix`: shared module that replaces the old Ansible roles (packages, audio, bluetooth, laptop/NVIDIA toggles).
- `overlays/suckless.nix`: overlay that builds `dwm`, `st`, `dmenu`, `dwmblocks`, `slock`, and `sbs` from the GitHub forks.
- `home/default.nix`: Home Manager module that ships all dotfiles in this repository.
- `etc` / `libinput`: configuration files that are linked into `/etc` on the target system.

## Bootstrap a machine

1. Boot a NixOS installer ISO and mount your target root (e.g. at `/mnt`).
2. Clone the repo into `/mnt/etc/nixos` (or another workspace) and enter it:
   ```console
   git clone https://github.com/onur-ozkan/nixconf
   cd nixconf
   ```
3. Generate a hardware profile for the machine and overwrite the placeholder:
   ```console
   sudo nixos-generate-config --root /mnt \
     --show-hardware-config > nixos/hosts/nimda/hardware-configuration.nix
   ```
4. Adjust host/user details in `nixos/hosts/nimda/configuration.nix` or `home/default.nix` if needed. Toggle laptop/Bluetooth/NVIDIA features via `nimda.profile` in the host file.
5. Build and switch (or install) using the flake:
   ```console
   sudo nixos-rebuild switch --flake .#nimda
   # or during installation
   sudo nixos-install --flake .#nimda
   ```

## Customization notes

- Add more hosts under `nixos/hosts/<name>` and expose them in `flake.nix`.
- Tweak the Home Manager profile in `home/default.nix` to add packages or services.
- Replace the placeholder hardware configuration every time you target a new machine (even virtual ones).
- Run `nix flake update` before rebuilding if you want to advance to newer versions of Nixpkgs/Home Manager or to refresh the personal suckless sources.
