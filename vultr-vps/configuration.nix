{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/k8s-vps.nix
    ./network.nix
  ];

  networking.hostName = "vultr-vps";

  kubernetesNode.nodeIP = "100.71.128.99";
}
