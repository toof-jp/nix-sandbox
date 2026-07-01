#!/bin/sh
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt $USER
