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

  networking.hostName = "sakura-vps";
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  kubernetesNode.nodeIP = "100.117.158.100";

  # No persistent swap: kubelet refuses to start with swap on unless it's
  # explicitly configured for cgroup v2 (NodeSwap feature gate +
  # memorySwap.swapBehavior), which we don't set up. The temporary
  # swapfile created by `sakura-install` before `nixos-install` (to avoid
  # OOM while building/copying the closure) is only used during install
  # and isn't declared here, so it's gone on first boot of this config.
  swapDevices = [ ];

  environment.systemPackages = with pkgs; [ vim git tmux wget htop ];

  # Longhorn stores replicas on this node (/var/lib/longhorn). Its v1 data
  # engine attaches volumes over iSCSI, so iscsid must run on the host.
  services.openiscsi = {
    enable = true;
    name = "iqn.2016-04.com.open-iscsi:${config.networking.hostName}";
  };
  # longhorn-manager nsenters the host mount namespace and invokes iscsiadm
  # etc. by absolute-ish PATH lookup (/usr/local/bin, /usr/bin, ...), none of
  # which exist on NixOS — expose the system profile there.
  systemd.tmpfiles.rules = [
    "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
  ];

  system.stateVersion = "26.05";

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN8H2c3Qa2EsEh6RQG6nRoRFblH8fj5dHj9YyVD9tND toof@toof.jp"
  ];

  programs.zsh.enable = true;
  users.users.root.shell = pkgs.zsh;
}
