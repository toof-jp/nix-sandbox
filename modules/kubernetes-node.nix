{ pkgs, lib, config, ... }:

{
  options.kubernetesNode.nodeIP = lib.mkOption {
    type = lib.types.str;
    description = ''
      Tailscale IP this node's kubelet advertises as its InternalIP, so
      cluster traffic (apiserver, kubelet, kube-proxy) flows over the
      tailscale mesh instead of whatever the kernel picks as the default
      route (usually the public interface).
    '';
  };

  config = {
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

    environment.systemPackages = [ pkgs.kubernetes pkgs.cri-tools ];

    # kubeadm (init or join) writes bootstrap-kubelet.conf and
    # /var/lib/kubelet/config.yaml, then expects a kubelet systemd unit to
    # already exist so it can `systemctl restart kubelet`. NixOS has no
    # distro package for that unit, so it is declared here for both the
    # control-plane and worker roles.
    systemd.services.kubelet = {
      description = "Kubernetes Kubelet";
      wantedBy = [ "multi-user.target" ];
      after = [ "containerd.service" ];
      path = [ pkgs.kubernetes pkgs.iproute2 pkgs.ethtool pkgs.socat pkgs.conntrack-tools pkgs.util-linux ];
      serviceConfig = {
        ExecStart = "${pkgs.kubernetes}/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --container-runtime-endpoint=unix:///run/containerd/containerd.sock --node-ip=${config.kubernetesNode.nodeIP}";
        Restart = "always";
        StartLimitIntervalSec = 0;
      };
    };

    # Node-to-node traffic (kubeadm join/init, apiserver, etcd, kubelet,
    # kube-proxy) all flow over the tailscale mesh instead of the public
    # internet. Interfaces trusted below only matter on hosts that also
    # enable the firewall. flannel.1/cni0 must be trusted too: pod ->
    # ClusterIP service traffic (e.g. CoreDNS -> kube-apiserver) is
    # DNAT'd by kube-proxy to the node's own address and arrives on
    # INPUT from those interfaces, not tailscale0 — without this,
    # CoreDNS can never reach the apiserver on a host with the firewall
    # enabled.
    services.tailscale.enable = true;
    services.tailscale.openFirewall = true;
    networking.firewall.trustedInterfaces = [ "tailscale0" "flannel.1" "cni0" ];
  };
}
