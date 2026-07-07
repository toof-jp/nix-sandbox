{ modulesPath, pkgs, lib, config, ... }:

# Shared installer-ISO module for the VPS hosts. Each host's installer.nix
# imports this, sets vpsInstaller.*, and adds host-specific networking if
# the provider has no DHCP (Sakura).
let
  cfg = config.vpsInstaller;

  installScript = pkgs.writeShellScriptBin cfg.scriptName ''
    set -euo pipefail

    if [ "$(id -u)" -ne 0 ]; then
      exec sudo "$0" "$@"
    fi

    echo "This will ERASE /dev/vda and install NixOS (${cfg.flakeAttr}). Type YES to continue:"
    read -r confirm
    if [ "$confirm" != "YES" ]; then
      echo "Aborted."
      exit 1
    fi

    parted /dev/vda -- mklabel gpt
    parted /dev/vda -- mkpart primary 1MiB 2MiB
    parted /dev/vda -- set 1 bios_grub on
    parted /dev/vda -- mkpart primary ext4 2MiB 100%
    mkfs.ext4 -L nixos /dev/vda2
    # mkfs and the by-label symlink race: udev may not have processed the
    # new label yet when mount runs (seen on Vultr: "Can't lookup blockdev").
    udevadm settle
    mount /dev/disk/by-label/nixos /mnt

    mkdir -p /mnt/var/lib
    dd if=/dev/zero of=/mnt/var/lib/swapfile bs=1M count=2048
    chmod 600 /mnt/var/lib/swapfile
    mkswap /mnt/var/lib/swapfile
    swapon /mnt/var/lib/swapfile

    NIX_CONFIG="experimental-features = nix-command flakes" \
      nixos-install --root /mnt --flake github:toof-jp/nix-sandbox#${cfg.flakeAttr} --no-root-passwd

    echo "Done. ${cfg.doneMessage}"
  '';
in
{
  options.vpsInstaller = {
    flakeAttr = lib.mkOption {
      type = lib.types.str;
      description = "nixosConfigurations attribute that nixos-install targets.";
    };
    scriptName = lib.mkOption {
      type = lib.types.str;
      description = "Name of the install command available in the live env.";
    };
    doneMessage = lib.mkOption {
      type = lib.types.str;
      default = "Detach the ISO, then reboot.";
      description = "Provider-specific instruction printed after install.";
    };
  };

  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  config = {
    # The installer profile ships ZFS support, which warns unless this is
    # set explicitly. The live env never imports a ZFS root, so opt into
    # the safer 26.11 default now.
    boot.zfs.forceImportRoot = false;

    # The default installer profile already enables sshd (PermitRootLogin
    # "yes") and root has no password — so nothing logs in until a key is
    # added here.
    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN8H2c3Qa2EsEh6RQG6nRoRFblH8fj5dHj9YyVD9tND toof@toof.jp"
    ];

    environment.systemPackages = with pkgs; [ git vim wget tmux installScript ];
  };
}
