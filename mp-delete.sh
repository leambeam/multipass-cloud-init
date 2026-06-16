#!/usr/bin/env bash

set -euo pipefail

vm_not_found() {
    while true; do
        read -r -p "VM \"$vm_name\" not found on Multipass. Delete any associated local files? (y/n): " answer
        case "$answer" in
        y) break ;;
        n) exit 1 ;;
        *) echo "Invalid choice. Use either y or n." >&2 ;;
        esac
    done
}

vm_name=${1:-}

if [[ -z "$vm_name" ]]; then
    echo "Usage: $0 <vm-name>" >&2
    exit 1
fi

readonly ssh_key_base="test"
readonly vm_key_dir="${ssh_key_base}/${vm_name}"
readonly generated_cloud_init_path="cloud-init-$vm_name.yaml"

if multipass info "$vm_name" &> /dev/null; then
    echo "Deleting \"$vm_name\"..."
    multipass delete "$vm_name" --purge
else
    vm_not_found
fi

ssh-keygen -R "${vm_name}.local"

if [[ -d "$vm_key_dir" ]]; then
    echo "Removing $vm_key_dir"
    rm -r "$vm_key_dir"
fi

if [[ -f "$generated_cloud_init_path" ]]; then
    echo "Removing $generated_cloud_init_path"
    rm "$generated_cloud_init_path"
fi