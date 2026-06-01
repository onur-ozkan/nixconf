{
  config,
  pkgs,
  lib,
  overrideRoot,
  repoRoot,
  resolvePath,
  ...
}: let
  homeDir = config.home.homeDirectory;
  mergeDirectorySource = relativePath: let
    overridePath = overrideRoot + "/${relativePath}";
    basePath = repoRoot + "/${relativePath}";
    sanitizedName = lib.replaceStrings ["/" "."] ["-" "-"] relativePath;
  in
    if builtins.pathExists overridePath
    then
      pkgs.runCommandLocal "nixconf-override-${sanitizedName}" {} ''
        mkdir -p "$out"
        cp -a ${basePath}/. "$out"/
        chmod -R u+w "$out"
        cp -a ${overridePath}/. "$out"/
      ''
    else basePath;
in {
  home.username = "nimda";
  home.homeDirectory = "/home/nimda";
  home.stateVersion = "26.05";
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
    envExtra = builtins.readFile (resolvePath ".zshenv");
    initContent = builtins.readFile (resolvePath ".zshrc");
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
          rev = "c28ec53";
          sha256 = "sha256-P+X2biB7yt9GIMzZ09neH0r0JeHyUYQvHhBJUsEXKMo=";
        };
      })
    ];
  };

  programs.tmux = {
    enable = true;
    extraConfig = builtins.readFile (resolvePath ".tmux.conf");
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*" = {
      ForwardAgent = false;
      AddKeysToAgent = "no";
      Compression = false;
      ServerAliveInterval = 0;
      ServerAliveCountMax = 3;
      HashKnownHosts = false;
      UserKnownHostsFile = "~/.ssh/known_hosts";
    };
    settings."git.orkavian.com" = {
      HostName = "git.orkavian.com";
      Port = 4022;
    };
    settings."ssh.gitlab.freedesktop.org" = {
      HostName = "ssh.gitlab.freedesktop.org";
      User = "git";
      IdentityFile = "${homeDir}/.ssh/gitlab_freedesktop_org";
      IdentitiesOnly = true;
    };
    settings."gitlab.com" = {
      HostName = "gitlab.com";
      User = "git";
      IdentityFile = "${homeDir}/.ssh/gitlab_com";
      IdentitiesOnly = true;
    };
  };

  home.file.".Xresources".source = resolvePath ".Xresources";
  home.file.".xinitrc".source = resolvePath ".xinitrc";
  home.file.".gitconfig".source = resolvePath ".gitconfig";
  home.file.".dircolors".source = resolvePath ".dircolors";

  home.file.".dwm" = {
    source = mergeDirectorySource ".dwm";
    recursive = true;
  };

  home.file.".local/share/fonts" = {
    source = mergeDirectorySource "fonts";
    recursive = true;
  };

  home.file.".local/bin" = {
    source = mergeDirectorySource ".local/bin";
    recursive = true;
  };

  home.file.".config/nvim" = {
    source = mergeDirectorySource ".config/nvim";
    recursive = true;
  };

  home.file.".config/remote-shell" = {
    source = mergeDirectorySource ".config/remote-shell";
    recursive = true;
  };

  home.file.".backgrounds" = {
    source = mergeDirectorySource ".backgrounds";
    recursive = true;
  };

  fonts.fontconfig.enable = true;
}
