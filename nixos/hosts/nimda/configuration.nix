{ config, pkgs, lib, inputs, ... }:

with lib;

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/packages.nix
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (import ../../overlays/suckless.nix { inherit inputs; })
  ];

  programs.nix-ld.enable = true;
  programs.zsh.enable = true;
  programs.slock.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=2 exclusive_caps=1
  '';

  networking.hostName = "nimda";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Istanbul";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users.users.nimda = {
    isNormalUser = true;
    description = "Onur Özkan";
    extraGroups = ["wheel" "networkmanager" "docker" "dialout"];
    shell = pkgs.zsh;
  };

  security.sudo.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  networking.firewall = {
    enable = true;
    allowPing = false;
    allowedUDPPorts = [69];
    allowedTCPPorts = [2049];
  };

  nimda.profile = {
    bluetooth = true;
    laptop = false;
    nvidia_5090_driver = false;
  };

  services.xserver = {
    enable = true;
    displayManager.startx.enable = true;
  };

  services.libinput = mkIf config.nimda.profile.laptop {
    enable = true;
    touchpad.naturalScrolling = true;
  };

  services.tftpd = {
    enable = false;
    path = "/srv/tftp";
  };

  services.nfs.server = {
    enable = false;
  };

  # NFSv4 pseudo-root export
  services.nfs.server.exports = ''
    /srv/nfs *(rw,sync,no_subtree_check,fsid=0,no_root_squash)
    /srv/nfs/opi5 *(rw,sync,no_subtree_check,no_root_squash)
  '';

  system.stateVersion = "25.11";
}
