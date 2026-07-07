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

  # The dhcpcd -> resolved handoff left resolved with zero global
  # nameservers, so /run/systemd/resolve/resolv.conf was empty and
  # coredns on this node crashlooped with "plugin/forward: no
  # nameservers found". Pin resolvers explicitly like sakura-vps does.
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
}
