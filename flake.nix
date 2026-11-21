{
  description = "Onur Özkan's reproducible NixOS + Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # DE sources
    dwm-enhanced = {
      url = "github:onur-ozkan/dwm-enhanced?rev=5e0e416063d460c4c39229ddd2287b9ed3deb772";
      flake = false;
    };
    st-enhanced = {
      url = "github:onur-ozkan/st-enhanced?rev=2995dbbc07b84297cbd357432f126e62e8c10437";
      flake = false;
    };
    dmenu-enhanced = {
      url = "github:onur-ozkan/dmenu-enhanced?rev=d1d8024cd87bdacfea0f53aa8935cd210fa547e8";
      flake = false;
    };
    dwmblocks-enhanced = {
      url = "github:onur-ozkan/dwmblocks-enhanced?rev=3ff1e40062b555bfbf00321ecb090dd994b0a367";
      flake = false;
    };
    slock-enhanced = {
      url = "github:onur-ozkan/slock-enhanced?rev=29af2c75bfe9cfac1f1108cd96ce65b0affb75c1";
      flake = false;
    };
    sbs = {
      url = "github:onur-ozkan/sbs?rev=cd378772b67210a6580443a13fe7a69d065bfd37";
      flake = false;
    };

    # Dev tooling
    opencode.url = "github:anomalyco/opencode/v1.19.5";
    mreply = {
      url = "github:onur-ozkan/mreply?rev=a2034f683c41b7a3e7d265aac0906b493c9a3da3";
      flake = false;
    };

    # Neovim plugins
    vim-plenary = {
      url = "github:nvim-lua/plenary.nvim?rev=74b06c6c75e4eeb3108ec01852001636d85a932b";
      flake = false;
    };
    vim-telescope = {
      url = "github:nvim-telescope/telescope.nvim?rev=40aedd8a68c78a656a10a8d62d80c54af59420fb";
      flake = false;
    };
    vim-tree = {
      url = "github:nvim-tree/nvim-tree.lua?rev=8d814495983e8db87d02d2f1da293f25b2fd1bdc";
      flake = false;
    };
    vim-mini-diff = {
      url = "github:nvim-mini/mini.diff?rev=91d6ce4b7f400439fe761f01a58280f2c0f99c01";
      flake = false;
    };
    vim-lspconfig = {
      url = "github:neovim/nvim-lspconfig?rev=ffd261c09c3dabd0bf1a438f47a8ae3b22f3c3ff";
      flake = false;
    };
    vim-cmp = {
      url = "github:hrsh7th/nvim-cmp?rev=2ffe79f1f021def8dd1fcd81deb16f1bb0d989f3";
      flake = false;
    };
    vim-cmp-lsp = {
      url = "github:hrsh7th/cmp-nvim-lsp?rev=cbc7b02bb99fae35cb42f514762b89b5126651ef";
      flake = false;
    };
    vim-cmp-buffer = {
      url = "github:hrsh7th/cmp-buffer?rev=b74fab3656eea9de20a9b8116afa3cfc4ec09657";
      flake = false;
    };
    vim-cmp-path = {
      url = "github:hrsh7th/cmp-path?rev=c642487086dbd9a93160e1679a1327be111cbc25";
      flake = false;
    };
    vim-lualine = {
      url = "github:nvim-lualine/lualine.nvim?rev=221ce6b2d999187044529f49da6554a92f740a96";
      flake = false;
    };
    vim-dark-energy = {
      url = "github:onur-ozkan/dark-energy.vim?rev=c28ec53530d1001edecb5b49517f70342e380db3";
      flake = false;
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    ...
  }: let
    inherit (nixpkgs.lib) genAttrs;
    systems = ["x86_64-linux"];
    repoRoot = ./.;
    overrideRoot = repoRoot + "/override";
    resolvePath = relativePath: let
      overridePath = overrideRoot + "/${relativePath}";
      defaultPath = repoRoot + "/${relativePath}";
    in
      if builtins.pathExists overridePath
      then overridePath
      else defaultPath;
  in {
    formatter = genAttrs systems (system: nixpkgs.legacyPackages.${system}.alejandra);

    nixosConfigurations.nimda = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs overrideRoot repoRoot resolvePath;
      };
      modules = [
        (resolvePath "nixos/hosts/nimda/configuration.nix")
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit inputs overrideRoot repoRoot resolvePath;
          };
          home-manager.users.nimda = import (resolvePath "nixos/home");
        }
      ];
    };

    devShells.x86_64-linux.lkdev = import (resolvePath "nixos/shells/lkdev.nix") {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      inherit resolvePath;
    };

    devShells.x86_64-linux.orkavian = import (resolvePath "nixos/shells/orkavian.nix") {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      inherit resolvePath;
    };

    devShells.x86_64-linux.kyber = import (resolvePath "nixos/shells/kyber.nix") {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      inherit resolvePath;
    };
  };
}
