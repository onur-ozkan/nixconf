{ config, lib, pkgs, ... }:

let
  cfg = config.nimda.profile;

  basePackages = with pkgs; [
    acpi
    bc
    brave
    claws-mail
    cmake
    config.boot.kernelPackages.perf
    curl
    dmenu-enhanced
    docker
    dwm-enhanced
    fd
    flameshot
    gcc
    git
    gnumake
    gnupg
    go
    htop
    inotify-tools
    pciutils
    pkg-config
    python3
    ripgrep
    rsync
    rustup
    sbs
    screenfetch
    signal-desktop
    slock-enhanced
    st-enhanced
    unzip
    usbutils
    vscode
    wget
    xclip
    xdg-utils
    xorg.setxkbmap
    xorg.xinit
    xorg.xrandr
    xorg.xrdb
    xorg.xset
    zip
  ];

  bluetoothPackages = with pkgs; [
    bluez
    bluez-tools
  ];

  laptopPackages = with pkgs; [
    brightnessctl
    power-profiles-daemon
    powertop
    xorg.xinput
  ];

  dwmblocksPatch =
    if cfg.laptop then
      ../patches/dwmblock-enhanced/laptop.patch
    else
      ../patches/dwmblock-enhanced/desktop.patch;

  dwmblocksEnhanced = pkgs.dwmblocks-enhanced.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ dwmblocksPatch ];
  });
in {
  options.nimda.profile = {
    bluetooth = lib.mkEnableOption "Bluetooth support packages and services";
    laptop = lib.mkEnableOption "Laptop specific tooling";
    nvidia_driver = lib.mkEnableOption "NVIDIA desktop GPU driver";
  };

  config = {
    environment.systemPackages =
      basePackages
      ++ [ dwmblocksEnhanced ]
      ++ lib.optionals cfg.bluetooth bluetoothPackages
      ++ lib.optionals cfg.laptop laptopPackages
      ++ lib.optionals cfg.nvidia_driver [ config.boot.kernelPackages.nvidiaPackages.production ];

    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-color-emoji
    ];

    services.pulseaudio.enable = false;
    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    hardware.bluetooth = lib.mkIf cfg.bluetooth {
      enable = true;
      powerOnBoot = true;
    };

    services.blueman.enable = cfg.bluetooth;
    services.power-profiles-daemon.enable = cfg.laptop;
    services.thermald.enable = cfg.laptop;
    virtualisation.docker.enable = true;

    services.xserver = lib.mkIf cfg.nvidia_driver {
      videoDrivers = [ "nvidia" ];
    };

    hardware.graphics = lib.mkIf cfg.nvidia_driver {
      enable = true;
    };

    hardware.nvidia = lib.mkIf cfg.nvidia_driver {
      modesetting.enable = true;
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
      powerManagement.enable = false;
    };
  };
}
