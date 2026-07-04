{ modulesPath, pkgs, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  # The default installer profile already enables sshd (PermitRootLogin
  # "yes") and DHCP via NetworkManager, and root has no password — so
  # nothing logs in until a key is added here. Sakura's VPS network hands
  # out a public IP over DHCP, so no static networking is needed.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN8H2c3Qa2EsEh6RQG6nRoRFblH8fj5dHj9YyVD9tND toof@toof.jp"
  ];

  environment.systemPackages = with pkgs; [ git vim wget tmux ];
}
