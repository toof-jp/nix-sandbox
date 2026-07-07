{ ... }:

# Unlike Sakura, Vultr hands out the public IPv4 over DHCP, so no static
# addressing is needed.
{
  networking.useDHCP = true;

  # kubeadm inherits the cluster-wide kubelet config, which points
  # resolvConf at /run/systemd/resolve/resolv.conf — that file only
  # exists when systemd-resolved is running. Without this every pod
  # sandbox creation fails with "no such file or directory".
  services.resolved.enable = true;
}
