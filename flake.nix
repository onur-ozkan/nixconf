{
  description = "Onur Özkan's reproducible NixOS + Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    dwm-enhanced = {
      url = "github:onur-ozkan/dwm-enhanced";
      flake = false;
    };
    st-enhanced = {
      url = "github:onur-ozkan/st-enhanced";
      flake = false;
    };
    dmenu-enhanced = {
      url = "github:onur-ozkan/dmenu-enhanced";
      flake = false;
    };
    dwmblocks-enhanced = {
      url = "github:onur-ozkan/dwmblocks-enhanced";
      flake = false;
    };
    slock-enhanced = {
      url = "github:onur-ozkan/slock-enhanced";
      flake = false;
    };
    sbs = {
      url = "github:onur-ozkan/sbs";
      flake = false;
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, ... }:
    let
      inherit (nixpkgs.lib) genAttrs;
      systems = [ "x86_64-linux" ];
    in {
      formatter = genAttrs systems (system: nixpkgs.legacyPackages.${system}.alejandra);

      nixosConfigurations.nimda = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./nixos/hosts/nimda/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.nimda = import ./home;
          }
        ];
      };
    };
  }
