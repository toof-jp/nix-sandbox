{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/k8s-vps.nix
    ./network.nix
    ./nemousu-redirect.nix
  ];

  networking.hostName = "sakura-vps";

  kubernetesNode.nodeIP = "100.117.158.100";

  # 3.8GiB control-plane running kube-apiserver, etcd, longhorn-manager.
  # Under memory spikes the node stops posting kubelet heartbeats and drops
  # off tailscale (see 2026-07-21 incident: NotReady 22:47, forced reboot).
  # Reservations keep kubelet/containerd/sshd/tailscaled in their own cgroup
  # and let eviction shed pods before the OS starts reclaiming from system
  # procs. Same values as vultr-vps (same VPS class).
  kubernetesNode.extraKubeletArgs = [
    "--system-reserved=cpu=100m,memory=300Mi"
    "--kube-reserved=cpu=100m,memory=300Mi"
    "--eviction-hard=memory.available<300Mi,nodefs.available<10%"
    "--eviction-minimum-reclaim=memory.available=100Mi,nodefs.available=5%"
  ];
}
