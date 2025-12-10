{ config, pkgs, ... }:

{
  home.username = "nimda";
  home.homeDirectory = "/home/nimda";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
  home.sessionVariables = {
    EDITOR = "nvim";
    TERMINAL = "st";
  };

  home.packages = with pkgs; [
    bat
    curl
    fd
    git
    ripgrep
    tmux
    unzip
    neovim
    wget
  ];

  programs.zsh = {
    enable = true;
    enableAutosuggestions = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
  };

  programs.tmux.enable = true;
  programs.git.enable = true;
  programs.ssh = {
    enable = true;
    matchBlocks."git.orkavian.com" = {
      hostname = "git.orkavian.com";
      port = 4022;
    };
  };

  home.file.".xdg-override/.keep".text = "";

  home.file.".zshenv".source = ../.zshenv;
  home.file.".zshrc".source = ../.zshrc;
  home.file.".Xresources".source = ../.Xresources;
  home.file.".xinitrc".source = ../.xinitrc;
  home.file.".tmux.conf".source = ../.tmux.conf;
  home.file.".gitconfig".source = ../.gitconfig;
  home.file.".dircolors".source = ../.dircolors;

  home.file.".dwm" = {
    source = ../.dwm;
    recursive = true;
  };

  home.file.".local/bin" = {
    source = ../.local/bin;
    recursive = true;
  };

  home.file.".config/nvim" = {
    source = ../.config/nvim;
    recursive = true;
  };

  home.file.".backgrounds" = {
    source = ../.backgrounds;
    recursive = true;
  };
}
