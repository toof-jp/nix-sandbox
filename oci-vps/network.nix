{ ... }:

# OCI hands out the private IP over DHCP (public IP is 1:1 NAT at the VCN
# edge), so DHCP is enough — same shape as vultr-vps.
{
  networking.useDHCP = true;

  # kubeadm inherits the cluster-wide kubelet config, which points
  # resolvConf at /run/systemd/resolve/resolv.conf — that file only
  # exists when systemd-resolved is running.
  services.resolved.enable = true;

  # Don't depend on the DHCP -> resolved handoff for global nameservers;
  # pin resolvers explicitly like the other VPS nodes.
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
}
