{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/system-packages.nix
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (import ../../../overlays/suckless.nix inputs)
  ];

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
    extraGroups = [ "wheel" "networkmanager" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;

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

  services.tlp.enable = false;

  nimda.profile = {
    bluetooth = true;
    laptop = false;
  };

  environment.etc."tlp.conf" = lib.mkIf config.services.tlp.enable {
    source = ../../../etc/tlp.conf;
  };
  environment.etc."X11/xorg.conf.d/40-libinput.conf".source = ../../../libinput/40-libinput.conf;

  services.xserver.enable = false;

  system.stateVersion = "25.11";
}
