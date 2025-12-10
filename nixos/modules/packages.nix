{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nimda.profile;

  basePackages = with pkgs; [
    acpi
    bat
    bc
    chrony
    cmake
    curl
    dmenu-enhanced
    docker
    dwm-enhanced
    dwmblocks-enhanced
    fd
    flameshot
    gcc
    git
    gnumake
    gnupg
    htop
    inotify-tools
    networkmanager
    pciutils
    qemu_kvm
    ripgrep
    rsync
    sbs
    slock-enhanced
    st-enhanced
    unzip
    usbutils
    valgrind
    wget
    xclip
    xdg-utils
    xorg.setxkbmap
    xorg.xrandr
    xorg.xrdb
    xorg.xset
    zip
    zsh
  ];

  bluetoothPackages = with pkgs; [
    bluez
  ];

  laptopPackages = with pkgs; [
    brightnessctl
    powertop
    xorg.xinput
  ];
in {
  options.nimda.profile = {
    bluetooth = mkEnableOption "Bluetooth support packages and services";
    laptop = mkEnableOption "Laptop specific tooling";
  };

  config = {
    environment.systemPackages =
      basePackages
      ++ optionals cfg.bluetooth bluetoothPackages
      ++ optionals cfg.laptop laptopPackages;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
      wireplumber.enable = true;
    };

    services.pulseaudio.enable = false;

    hardware.bluetooth = mkIf cfg.bluetooth {
      enable = true;
      powerOnBoot = true;
    };

    services.blueman.enable = cfg.bluetooth;
    services.thermald.enable = cfg.laptop;
  };
}
