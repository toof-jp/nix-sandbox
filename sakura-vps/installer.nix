{ modulesPath, pkgs, ... }:

let
  sakuraInstall = pkgs.writeShellScriptBin "sakura-install" ''
    set -euo pipefail

    echo "This will ERASE /dev/vda and install NixOS (sakura-vps). Type YES to continue:"
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
    mount /dev/disk/by-label/nixos /mnt

    mkdir -p /mnt/var/lib
    dd if=/dev/zero of=/mnt/var/lib/swapfile bs=1M count=2048
    chmod 600 /mnt/var/lib/swapfile
    mkswap /mnt/var/lib/swapfile
    swapon /mnt/var/lib/swapfile

    NIX_CONFIG="experimental-features = nix-command flakes" \
      nixos-install --root /mnt --flake github:toof-jp/nix-sandbox#sakura-vps --no-root-passwd

    echo "Done. Unmount the ISO in the Sakura control panel, then reboot."
  '';
in
{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    ./network.nix
  ];

  # The default installer profile already enables sshd (PermitRootLogin
  # "yes") and root has no password — so nothing logs in until a key is
  # added here. Static networking comes from network.nix, so no manual
  # `ip addr add` is needed after boot.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN8H2c3Qa2EsEh6RQG6nRoRFblH8fj5dHj9YyVD9tND toof@toof.jp"
  ];

  environment.systemPackages = with pkgs; [ git vim wget tmux sakuraInstall ];
}
