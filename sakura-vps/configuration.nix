{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../modules/k8s-vps.nix
    ./network.nix
  ];

  networking.hostName = "sakura-vps";

  kubernetesNode.nodeIP = "100.117.158.100";
}
