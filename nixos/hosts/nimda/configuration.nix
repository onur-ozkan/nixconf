{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/packages.nix
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (import ../../overlays/suckless.nix { inherit inputs; })
  ];

  programs.nix-ld.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nimda";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Istanbul";
  i18n.defaultLocale = "en_US.UTF-8";
  console.keyMap = "us";

  users.users.nimda = {
    isNormalUser = true;
    description = "Onur Özkan";
    extraGroups = [ "wheel" "networkmanager" "docker" ];
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

  system.stateVersion = "25.11";
}
