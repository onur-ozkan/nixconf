{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nimda.profile;
  nvidia5090DriverPackage = config.boot.kernelPackages.nvidiaPackages.production;

  basePackages = with pkgs; [
    acpi
    bat
    bc
    brave
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
    pamixer
    pavucontrol
    pciutils
    qemu_kvm
    ripgrep
    rsync
    sbs
    screenfetch
    slock-enhanced
    st-enhanced
    unzip
    usbutils
    valgrind
    wget
    xclip
    xdg-utils
    xorg.setxkbmap
    xorg.xinit
    xorg.xrandr
    xorg.xrdb
    xorg.xset
    zip
    zsh
  ];

  bluetoothPackages = with pkgs; [
    bluez
    bluez-tools
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
    nvidia_5090_driver = mkEnableOption "NVIDIA 5090 desktop GPU driver";
  };

  config = {
    environment.systemPackages =
      basePackages
      ++ optionals cfg.bluetooth bluetoothPackages
      ++ optionals cfg.laptop laptopPackages
      ++ optionals cfg.nvidia_5090_driver [ nvidia5090DriverPackage ];

    hardware.pulseaudio.enable = false;
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };

    hardware.bluetooth = mkIf cfg.bluetooth {
      enable = true;
      powerOnBoot = true;
    };

    services.blueman.enable = cfg.bluetooth;
    services.thermald.enable = cfg.laptop;

    services.xserver = mkIf cfg.nvidia_5090_driver {
      videoDrivers = [ "nvidia" ];
    };

    hardware.opengl = mkIf cfg.nvidia_5090_driver {
      enable = true;
    };

    hardware.nvidia = mkIf cfg.nvidia_5090_driver {
      modesetting.enable = true;
      open = true;
      package = nvidia5090DriverPackage;
      powerManagement.enable = false;
    };
  };
}
