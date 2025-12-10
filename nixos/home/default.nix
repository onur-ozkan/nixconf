{ config, pkgs, lib, ... }:

let
  homeDir = config.home.homeDirectory;
  nvimPkg = config.programs.neovim.finalPackage or pkgs.neovim;
in {
  home.username = "nimda";
  home.homeDirectory = "/home/nimda";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
  home.sessionVariables = {
    EDITOR = "nvim";
    TERMINAL = "st";
  };

  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    envExtra = builtins.readFile ../../.zshenv;
    initExtra = builtins.readFile ../../.zshrc;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
  };

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile ../../.tmux.conf;
  };
  programs.ssh = {
    enable = true;
    matchBlocks."git.orkavian.com" = {
      hostname = "git.orkavian.com";
      port = 4022;
    };
  };

  home.file.".Xresources".source = ../../.Xresources;
  home.file.".xinitrc".source = ../../.xinitrc;
  home.file.".gitconfig".source = ../../.gitconfig;
  home.file.".dircolors".source = ../../.dircolors;

  home.file.".dwm" = {
    source = ../../.dwm;
    recursive = true;
  };

  home.file.".local/share/fonts" = {
    source = ../../fonts;
    recursive = true;
  };

  home.file.".local/bin" = {
    source = ../../.local/bin;
    recursive = true;
  };

  home.file.".config/nvim" = {
    source = ../../.config/nvim;
    recursive = true;
  };

  home.file.".local/share/nvim/site/autoload/plug.vim".source = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim";
    sha256 = "sha256-4JmeVzBIZedfWxXuhjfcTOW6lZF1V/OPfLY9RUtTz7Q=";
  };

  home.file.".backgrounds" = {
    source = ../../.backgrounds;
    recursive = true;
  };

  fonts.fontconfig.enable = true;
}
