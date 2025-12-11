NixOS bootstrapper that sets up my development environment on top of
[dwm-enhanced](https://github.com/onur-ozkan/dwm-enhanced).

<img width="1921" height="1201" alt="2025-12-11_15-56" src="https://github.com/user-attachments/assets/afa3ff9e-8174-47cb-8f15-cd8282ce905a" />

## Bootstrap

1. Replace the placeholder `nixos/hosts/nimda/hardware-configuration.nix` with
the actual `hardware-configuration.nix` of the system. 

2. Adjust host/user details in `nixos/hosts/nimda/configuration.nix` and `nixos/home/default.nix`.

3. (optional) Review the patches in `nixos/patches` and modify or remove any you don't
need (if you remove any, you may need to update dwmblocksPatch in `nixos/modules/packages.nix`).

4. Run:

```
   sudo nixos-rebuild switch --flake .#nimda
```
