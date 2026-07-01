{
  description = "nix-sandbox VM configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.nixos-test = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./nixos-test/configuration.nix
      ];
    };
  };
}
