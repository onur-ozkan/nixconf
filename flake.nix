{
  description = "Onur Özkan's reproducible NixOS + Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    dwm-enhanced = {
      url = "github:onur-ozkan/dwm-enhanced?rev=b7aa0a1fa92ddc0ea5063c221f95e6d3ec06c3d8";
      flake = false;
    };
    st-enhanced = {
      url = "github:onur-ozkan/st-enhanced?rev=87d3220955b5c21ffc9bee4d63f3362a5a6adb3f";
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
            home-manager.users.nimda = import ./nixos/home;
          }
        ];
      };

      devShells.x86_64-linux.lkdev = import ./nixos/shells/lkdev.nix {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
      };
    };
  }
