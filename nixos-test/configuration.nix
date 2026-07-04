{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/kubernetes-node.nix
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "claude-code" "codex" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200n8" ];

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  environment.systemPackages = [ pkgs.vim pkgs.htop ];

  system.stateVersion = "26.05";

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN8H2c3Qa2EsEh6RQG6nRoRFblH8fj5dHj9YyVD9tND toof@toof.jp"
  ];

  programs.zsh.enable = true;
  users.users.root.shell = pkgs.zsh;
}
