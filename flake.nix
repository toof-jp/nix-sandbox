{
  description = "nix-sandbox VM configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dotfiles = {
      url = "github:toof-jp/dotfiles";
      flake = false;
    };
    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, home-manager, dotfiles, herdr }:
    let
      withHomeManager = module: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          module
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.extraSpecialArgs = { inherit inputs; };
            home-manager.users.root = import ./home;
          }
        ];
      };
    in
    {
      nixosConfigurations.nixos-test = withHomeManager ./nixos-test/configuration.nix;

      # sakura-vps is a k8s node, not a dev box — no home-manager dotfiles
      # (herdr/claude-code/codex/neovim are heavy to build/fetch on a small
      # VPS). `vim` is already in its environment.systemPackages.
      nixosConfigurations.sakura-vps = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./sakura-vps/configuration.nix ];
      };

      # `nix build .#nixosConfigurations.sakura-installer.config.system.build.isoImage`
      # produces the custom installer ISO to upload/mount via Sakura's VPS
      # control panel. No home-manager here — it's a throwaway live env.
      nixosConfigurations.sakura-installer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./sakura-vps/installer.nix ];
      };

      homeConfigurations.toof = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "aarch64-darwin";
          config.allowUnfreePredicate = pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" "codex" ];
        };
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./home
          {
            home.username = "toof";
            home.homeDirectory = "/Users/toof";
          }
        ];
      };
    };
}
