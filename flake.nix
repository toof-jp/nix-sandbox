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

      # The VPS hosts are k8s nodes, not dev boxes — no home-manager dotfiles
      # (herdr/claude-code/codex/neovim are heavy to build/fetch on a small
      # VPS). `vim` is already in their environment.systemPackages.
      nixosConfigurations.sakura-vps = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./sakura-vps/configuration.nix ];
      };

      nixosConfigurations.vultr-vps = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./vultr-vps/configuration.nix ];
      };

      # `make sakura-iso` / `make vultr-iso` build the custom installer ISOs
      # to upload/mount via each provider's control panel (or, for Vultr,
      # vultr_iso_private in toof-jp/infra terraform). No home-manager here —
      # they're throwaway live envs.
      nixosConfigurations.sakura-installer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./sakura-vps/installer.nix ];
      };

      nixosConfigurations.vultr-installer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./vultr-vps/installer.nix ];
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
