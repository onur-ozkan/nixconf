{
  pkgs,
  lib,
  inputs,
  ...
}: let
  neovimPlugins = lib.mapAttrs (name: spec:
    pkgs.vimUtils.buildVimPlugin {
      pname = name;
      version = inputs.${name}.shortRev;
      src = inputs.${name};
      dependencies = map (dependency: neovimPlugins.${dependency}) (spec.dependencies or []);
      # Check public entry points, not upstream test files or optional integrations.
      nvimRequireCheck = spec.modules or [];
    }) {
    vim-plenary = {modules = ["plenary.async"];};
    vim-telescope = {
      modules = ["telescope"];
      dependencies = ["vim-plenary"];
    };
    vim-tree = {modules = ["nvim-tree"];};
    vim-lspconfig = {modules = ["lspconfig.util"];};
    vim-cmp = {modules = ["cmp"];};
    vim-cmp-lsp = {
      modules = ["cmp_nvim_lsp"];
      dependencies = ["vim-cmp"];
    };
    vim-cmp-buffer = {
      modules = ["cmp_buffer"];
      dependencies = ["vim-cmp"];
    };
    vim-cmp-path = {
      modules = ["cmp_path"];
      dependencies = ["vim-cmp"];
    };
    vim-lualine = {modules = ["lualine"];};
    vim-dark-energy = {};
  };
in {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    vimAlias = true;
    viAlias = true;
    plugins = builtins.attrValues neovimPlugins;
  };
}
