{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nimda.profile;

  basePackages = with pkgs; [
    acpi
    bc
    chrony
    cmake
    curl
    fd
    flameshot
    gcc
    git
    gnupg
    htop
    inotify-tools
    gnumake
    neovim
    networkmanager
    pciutils
    podman
    qemu_kvm
    ripgrep
    rsync
    setxkbmap
    tmux
    unzip
    usbutils
    valgrind
    wget
    xclip
    xdg-utils
    xorg.xrandr
    xorg.xrdb
    xorg.xset
    zip
    zsh
    zsh-autosuggestions
    zsh-syntax-highlighting
    dwm-enhanced
    st-enhanced
    dmenu-enhanced
    dwmblocks-enhanced
    slock-enhanced
    sbs
  ];

  bluetoothPackages = with pkgs; [
    bluez
  ];

  laptopPackages = with pkgs; [
    brightnessctl
    powertop
    xinput
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

    hardware.pulseaudio.enable = false;

    hardware.bluetooth = mkIf cfg.bluetooth {
      enable = true;
      powerOnBoot = true;
    };

    services.blueman.enable = cfg.bluetooth;
    services.thermald.enable = cfg.laptop;
  };
}
