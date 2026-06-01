{
  description = "Onur Özkan's reproducible NixOS + Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    dwm-enhanced = {
      url = "github:onur-ozkan/dwm-enhanced?rev=45c9dbd4902ce800584f8c4aef80ac5f6e15b94d";
      flake = false;
    };
    st-enhanced = {
      url = "github:onur-ozkan/st-enhanced?rev=25fd67c02859822a966d3dc1adbd218647329946";
      flake = false;
    };
    dmenu-enhanced = {
      url = "github:onur-ozkan/dmenu-enhanced?rev=8af4894f35bc874ae84e3c523b7e87c2f1bfce6c";
      flake = false;
    };
    dwmblocks-enhanced = {
      url = "github:onur-ozkan/dwmblocks-enhanced?rev=04d53927255638ca2ea075ac41dc04c1c0d75305";
      flake = false;
    };
    slock-enhanced = {
      url = "github:onur-ozkan/slock-enhanced?rev=a340fb8f74c15c8d4f3586b5341c915485c615a4";
      flake = false;
    };
    sbs = {
      url = "github:onur-ozkan/sbs?rev=2cf5b9838a2da25522f61d7b29448fda81dc0167";
      flake = false;
    };
    mreply = {
      url = "github:onur-ozkan/mreply?rev=a2034f683c41b7a3e7d265aac0906b493c9a3da3";
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
            inherit overrideRoot repoRoot resolvePath;
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
