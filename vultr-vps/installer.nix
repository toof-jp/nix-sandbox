{ ... }:

{
  # Vultr's network is DHCP, which the minimal installer profile already
  # enables — no static network module needed here (cf. sakura-vps).
  imports = [ ../modules/vps-installer.nix ];

  vpsInstaller = {
    flakeAttr = "vultr-vps";
    scriptName = "vultr-install";
    doneMessage = "Detach the ISO (vultr_attach_iso = false in toof-jp/infra terraform), then reboot.";
  };
}
