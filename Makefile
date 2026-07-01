VM_NAME := nixos-test
VM_IP := 192.168.122.69
ISO_DIR := $(CURDIR)/iso
BOOT_DIR := /var/lib/libvirt/boot

.PHONY: create connect rescue ssh deploy

create:
	ISO_PATH="$$(find $(ISO_DIR) -maxdepth 1 -name '*.iso' -type f | sort | tail -n 1)"; \
	if [ -z "$$ISO_PATH" ]; then echo "No .iso file found in $(ISO_DIR)" >&2; exit 1; fi; \
	echo "Using ISO: $$ISO_PATH"; \
	GRUB_CFG="$$(isoinfo -R -i "$$ISO_PATH" -x /EFI/BOOT/grub.cfg 2>/dev/null)"; \
	KERNEL_LINE="$$(printf '%s\n' "$$GRUB_CFG" | grep -m1 -E '^[[:space:]]*linux /boot' || true)"; \
	INITRD_LINE="$$(printf '%s\n' "$$GRUB_CFG" | grep -m1 -E '^[[:space:]]*initrd /boot' || true)"; \
	if [ -z "$$KERNEL_LINE" ] || [ -z "$$INITRD_LINE" ]; then echo "Could not find kernel/initrd entries in $$ISO_PATH's grub.cfg" >&2; exit 1; fi; \
	KERNEL_REL="$$(printf '%s\n' "$$KERNEL_LINE" | awk '{print $$2}' | sed -E 's#^/+##; s#//+#/#g')"; \
	INITRD_REL="$$(printf '%s\n' "$$INITRD_LINE" | awk '{print $$2}' | sed -E 's#^/+##; s#//+#/#g')"; \
	KERNEL_ARGS="$$(printf '%s\n' "$$KERNEL_LINE" | sed -E 's#^[[:space:]]*linux[[:space:]]+\S+[[:space:]]+##' | sed -E 's/\$$\{isoboot\}//' | sed -E 's/^[[:space:]]+|[[:space:]]+$$//g')"; \
	sudo modprobe sch_htb; \
	if [ "$$(sudo virsh net-info default | awk '/^Active:/ {print $$2}')" != "yes" ]; then sudo virsh net-start default; fi; \
	sudo virsh net-autostart default; \
	sudo virt-install \
	  --name $(VM_NAME) \
	  --memory 4096 \
	  --vcpus 2 \
	  --disk size=40,path=/var/lib/libvirt/images/$(VM_NAME).qcow2,format=qcow2 \
	  --location "$$ISO_PATH,kernel=$$KERNEL_REL,initrd=$$INITRD_REL" \
	  --extra-args "console=tty0 console=ttyS0,115200n8 $$KERNEL_ARGS" \
	  --os-variant linux2022 \
	  --network network=default \
	  --graphics none \
	  --console pty,target_type=serial \
	  --boot uefi

connect:
	if [ "$$(sudo virsh domstate $(VM_NAME))" = "running" ]; then \
	  sudo virsh console $(VM_NAME); \
	else \
	  sudo virsh start $(VM_NAME) --console; \
	fi

rescue:
	ISO_PATH="$$(find $(ISO_DIR) -maxdepth 1 -name '*.iso' -type f | sort | tail -n 1)"; \
	if [ -z "$$ISO_PATH" ]; then echo "No .iso file found in $(ISO_DIR)" >&2; exit 1; fi; \
	echo "Using ISO: $$ISO_PATH"; \
	GRUB_CFG="$$(isoinfo -R -i "$$ISO_PATH" -x /EFI/BOOT/grub.cfg 2>/dev/null)"; \
	KERNEL_LINE="$$(printf '%s\n' "$$GRUB_CFG" | grep -m1 -E '^[[:space:]]*linux /boot' || true)"; \
	INITRD_LINE="$$(printf '%s\n' "$$GRUB_CFG" | grep -m1 -E '^[[:space:]]*initrd /boot' || true)"; \
	if [ -z "$$KERNEL_LINE" ] || [ -z "$$INITRD_LINE" ]; then echo "Could not find kernel/initrd entries in $$ISO_PATH's grub.cfg" >&2; exit 1; fi; \
	KERNEL_REL="$$(printf '%s\n' "$$KERNEL_LINE" | awk '{print $$2}' | sed -E 's#^/+##; s#//+#/#g')"; \
	INITRD_REL="$$(printf '%s\n' "$$INITRD_LINE" | awk '{print $$2}' | sed -E 's#^/+##; s#//+#/#g')"; \
	KERNEL_ARGS="$$(printf '%s\n' "$$KERNEL_LINE" | sed -E 's#^[[:space:]]*linux[[:space:]]+\S+[[:space:]]+##' | sed -E 's/\$$\{isoboot\}//' | sed -E 's/^[[:space:]]+|[[:space:]]+$$//g')"; \
	sudo mkdir -p $(BOOT_DIR); \
	isoinfo -R -i "$$ISO_PATH" -x "/$$KERNEL_REL" | sudo tee $(BOOT_DIR)/$(VM_NAME)-rescue-bzImage > /dev/null; \
	isoinfo -R -i "$$ISO_PATH" -x "/$$INITRD_REL" | sudo tee $(BOOT_DIR)/$(VM_NAME)-rescue-initrd > /dev/null; \
	sudo virsh destroy $(VM_NAME) 2>/dev/null || true; \
	sudo virt-xml $(VM_NAME) --edit target=sda --disk "path=$$ISO_PATH"; \
	sudo virt-xml $(VM_NAME) --edit --boot \
	  "kernel=$(BOOT_DIR)/$(VM_NAME)-rescue-bzImage,initrd=$(BOOT_DIR)/$(VM_NAME)-rescue-initrd,kernel_args=\"console=tty0 console=ttyS0,115200n8 $$KERNEL_ARGS\""; \
	sudo virsh start $(VM_NAME) --console

ssh:
	ssh root@$(VM_IP)

deploy:
	nix run nixpkgs#nixos-rebuild -- switch --flake .#$(VM_NAME) --target-host root@$(VM_IP) --build-host localhost
