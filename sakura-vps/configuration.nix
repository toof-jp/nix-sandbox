{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/kubernetes-node.nix
    ./network.nix
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "claude-code" "codex" ];

  # Sakura's VPS boots in legacy BIOS mode with a single virtio disk, so a
  # BIOS-boot partition plus GRUB on /dev/vda is enough — no EFI/ESP needed.
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # Persistent swap to avoid OOM under memory pressure (kubeadm/etcd are
  # not light). Mirrors the temporary swapfile created by hand before
  # `nixos-install` (see README) so the VPS still has swap after reboot.
  swapDevices = [
    { device = "/var/lib/swapfile"; size = 2048; }
  ];

  environment.systemPackages = with pkgs; [ vim git tmux wget htop ];

  system.stateVersion = "26.05";

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN8H2c3Qa2EsEh6RQG6nRoRFblH8fj5dHj9YyVD9tND toof@toof.jp"
  ];

  programs.zsh.enable = true;
  users.users.root.shell = pkgs.zsh;
}
