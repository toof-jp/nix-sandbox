{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200n8" ];

  networking.networkmanager.enable = true;
  networking.firewall.enable = false;

  boot.kernelModules = [ "overlay" "br_netfilter" ];
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
  };

  virtualisation.containerd.enable = true;
  virtualisation.containerd.settings.plugins."io.containerd.grpc.v1.cri".cni.bin_dir = "/opt/cni/bin";

  system.activationScripts.cniPlugins = ''
    mkdir -p /opt/cni/bin
    for f in ${pkgs.cni-plugins}/bin/*; do
      ln -sf "$f" /opt/cni/bin/
    done
  '';

  environment.systemPackages = [ pkgs.vim pkgs.kubernetes pkgs.cri-tools pkgs.htop ];

  systemd.services.kubelet = {
    description = "Kubernetes Kubelet";
    wantedBy = [ "multi-user.target" ];
    after = [ "containerd.service" ];
    path = [ pkgs.kubernetes pkgs.iproute2 pkgs.ethtool pkgs.socat pkgs.conntrack-tools pkgs.util-linux ];
    serviceConfig = {
      ExecStart = "${pkgs.kubernetes}/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --container-runtime-endpoint=unix:///run/containerd/containerd.sock";
      Restart = "always";
      StartLimitIntervalSec = 0;
    };
  };

  system.stateVersion = "26.05";

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN8H2c3Qa2EsEh6RQG6nRoRFblH8fj5dHj9YyVD9tND toof@toof.jp"
  ];
}
