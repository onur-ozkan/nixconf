{ config, pkgs, lib, ... }:

let
  homeDir = config.home.homeDirectory;
in {
  home.username = "nimda";
  home.homeDirectory = "/home/nimda";
  home.stateVersion = "25.11";
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.local/bin/statusbar"
  ];
  home.sessionVariables = {
    EDITOR = "nvim";
    TERMINAL = "st";
  };

  programs.home-manager.enable = true;

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    envExtra = builtins.readFile ../../.zshenv;
    initContent = builtins.readFile ../../.zshrc;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
    plugins = with pkgs.vimPlugins; [
      plenary-nvim
      telescope-nvim
      nvim-tree-lua
      nvim-lspconfig
      nvim-cmp
      cmp-nvim-lsp
      lualine-nvim
      (pkgs.vimUtils.buildVimPlugin {
        pname = "dark-energy-vim";
        version = "unstable";
        src = pkgs.fetchFromGitHub {
          owner = "onur-ozkan";
          repo = "dark-energy.vim";
          rev = "31afba7";
          sha256 = "sha256-BtRpyRpLRJl/gMZCF51ltgifAqwxXWpQ+OXm2Yy6wZQ=";
        };
      })
      (pkgs.vimUtils.buildVimPlugin {
        pname = "vim-esearch";
        version = "unstable";
        src = pkgs.fetchFromGitHub {
          owner = "onur-ozkan-backups";
          repo = "vim-esearch";
          rev = "d4703a6";
          sha256 = "sha256-Aett3CSMbLYFaWIRYIRCQXG9xl0qUZQK1CUER4ggKkc=";
        };
        doCheck = false;
      })
    ];
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
    matchBlocks."ssh.gitlab.freedesktop.org" = {
      hostname = "ssh.gitlab.freedesktop.org";
      user = "git";
      identityFile = "${homeDir}/.ssh/gitlab_freedesktop_org";
      identitiesOnly = true;
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

  home.file.".config/remote-shell" = {
    source = ../../.config/remote-shell;
    recursive = true;
  };

  home.file.".backgrounds" = {
    source = ../../.backgrounds;
    recursive = true;
  };

  fonts.fontconfig.enable = true;
}
