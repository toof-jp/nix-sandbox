{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/k8s-vps.nix
    ./network.nix
  ];

  networking.hostName = "vultr-vps";

  # TODO: replace with this node's Tailscale IP after the first boot:
  # `tailscale up`, read the IP from `tailscale ip -4`, set it here, then
  # `make deploy` (or nixos-rebuild switch) BEFORE running kubeadm join.
  # The placeholder only breaks kubelet, which is nonfunctional pre-join
  # anyway.
  kubernetesNode.nodeIP = "127.0.0.1";
}
