{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # This is only a placeholder. Replace the root device with the output of
  # `nixos-generate-config --show-hardware-config` for the machine you are
  # bootstrapping.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  swapDevices = [ ];
}
