{ ... }:

{
  imports = [
    ../modules/vps-installer.nix
    # Sakura's network has no DHCP, so the live env needs the same static
    # config as the installed system to be reachable over SSH.
    ./network.nix
  ];

  vpsInstaller = {
    flakeAttr = "sakura-vps";
    scriptName = "sakura-install";
    doneMessage = "Unmount the ISO in the Sakura control panel, then reboot.";
  };
}
