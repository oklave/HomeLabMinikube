#!/bin/bash

# Script to create Ubuntu 24.04 Cloud template in Proxmox
# Run as root or with sudo

set -e  # Stop on error

# Configuration
VM_ID=9000
VM_NAME="ubuntu-24.04-cloud"
MEMORY=2048
CORES=2
STORAGE="local-lvm"
BRIDGE="vmbr0"
IMAGE_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
IMAGE_PATH="/var/lib/vz/template/iso/ubuntu-24.04-cloud.img"

echo "=== Creating Ubuntu 24.04 Cloud template in Proxmox ==="

# Check permissions
if [ "$EUID" -ne 0 ]; then 
    echo "Please run this script as root (using sudo)"
    exit 1
fi

# Check if VM with this ID already exists
if qm status $VM_ID &>/dev/null; then
    echo "Error: VM with ID $VM_ID already exists"
    exit 1
fi

# 1. Download Cloud image
echo "1. Downloading Ubuntu 24.04 Cloud Image..."
if [ -f "$IMAGE_PATH" ]; then
    echo "   File already exists, skipping download"
else
    wget -O "$IMAGE_PATH" "$IMAGE_URL"
    echo "   Download completed"
fi

# 2. Create base VM
echo "2. Creating virtual machine ID $VM_ID..."
qm create $VM_ID --memory $MEMORY --cores $CORES --net0 virtio,bridge=$BRIDGE --name $VM_NAME

# 3. Import disk
echo "3. Importing disk to storage $STORAGE..."
qm importdisk $VM_ID "$IMAGE_PATH" $STORAGE

# 4. Configure VM hardware
echo "4. Configuring VM settings..."
qm set $VM_ID --scsihw virtio-scsi-pci --scsi0 $STORAGE:vm-$VM_ID-disk-0
qm set $VM_ID --ide2 $STORAGE:cloudinit
qm set $VM_ID --boot order=scsi0
qm set $VM_ID --agent enabled=1

# Additional settings (optional)
qm set $VM_ID --serial0 socket --vga serial0  # For serial console access
qm set $VM_ID --ipconfig0 ip=dhcp              # DHCP for network interface

# 5. Convert to template
echo "5. Converting to template..."
qm template $VM_ID

echo "=== Done! ==="
echo "Ubuntu 24.04 Cloud template created with ID $VM_ID"
echo ""
echo "To create a VM from this template:"
echo "  qm clone $VM_ID <new_ID> --name <vm_name>"
echo ""
echo "Example:"
echo "  qm clone 9000 100 --name my-ubuntu-vm"
