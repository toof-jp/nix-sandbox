{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/k8s-vps.nix
    ./network.nix
  ];

  networking.hostName = "vultr-vps";

  kubernetesNode.nodeIP = "100.71.128.99";

  # kube-apiserver alone takes ~1.8GiB on this 4GB control-plane, pushing
  # node memory to ~80%. Under that pressure every probe on the node times
  # out simultaneously (apiserver readiness 500, longhorn-manager/csi/engine
  # probe timeouts, node-exporter restarts every ~14min). Reservations keep
  # kubelet, containerd, sshd, tailscaled in their own cgroup so they don't
  # stall; eviction trips before the OS starts reclaiming from system procs.
  # eviction-minimum-reclaim avoids per-cycle micro-reclaim thrash.
  kubernetesNode.extraKubeletArgs = [
    "--system-reserved=cpu=100m,memory=300Mi"
    "--kube-reserved=cpu=100m,memory=300Mi"
    "--eviction-hard=memory.available<300Mi,nodefs.available<10%"
    "--eviction-minimum-reclaim=memory.available=100Mi,nodefs.available=5%"
  ];
}
