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
}
