#!/bin/bash
set -e

# Build the patched driver
make

# Backup existing drivers to allow restoration later
find /lib/modules/$(uname -r)/kernel/drivers/platform/x86/hp -name "hp-wmi.ko*" | while read -r OLD_DRIVER; do
    if [[ "$OLD_DRIVER" == *"$(pwd)"* ]]; then continue; fi
    
    if [[ "$OLD_DRIVER" != *".bak" ]]; then
        if [ ! -f "$OLD_DRIVER.bak" ]; then
            echo "Backing up old driver: $OLD_DRIVER"
            sudo mv "$OLD_DRIVER" "$OLD_DRIVER.bak"
        else
            echo "Backup already exists for $OLD_DRIVER, skipping overwrite."
            if [ -f "$OLD_DRIVER" ]; then
                 echo "Removing conflicting driver: $OLD_DRIVER"
                 sudo rm "$OLD_DRIVER"
            fi
        fi
    fi
done

# Install the new driver
DEST_DIR="/lib/modules/$(uname -r)/kernel/drivers/platform/x86/hp"
sudo mkdir -p "$DEST_DIR"
echo "Installing new driver to: $DEST_DIR/hp-wmi.ko"
sudo install -m 644 hp-wmi.ko "$DEST_DIR/hp-wmi.ko"

# Update module dependencies
sudo depmod -a

# Load the new driver
if sudo modprobe -r hp-wmi; then
    sudo modprobe hp-wmi
    echo "New driver loaded!"
else
    echo "Error: Could not unload old driver. Is your GUI or a monitor running?"
    echo "Try closing everything and running 'sudo modprobe -r hp-wmi' manually."
fi

# Update initramfs for persistence across reboots
if command -v update-initramfs >/dev/null; then
    sudo update-initramfs -u
elif command -v mkinitcpio >/dev/null; then
    sudo mkinitcpio -P
elif command -v dracut >/dev/null; then
    sudo dracut --force
fi

make clean