{ lib, ... }:

# Sakura's VPS network has no DHCP — the fixed IP, gateway, and netmask
# shown in the control panel's server -> network tab must be configured
# by hand. 255.255.254.0 is a /23.
{
  networking.networkmanager.enable = lib.mkForce false;
  networking.useDHCP = false;
  networking.interfaces.ens3.ipv4.addresses = [
    {
      address = "153.126.161.157";
      prefixLength = 23;
    }
  ];
  networking.defaultGateway = "153.126.160.1";
  networking.nameservers = [ "133.242.0.3" "210.188.224.10" ];
}
