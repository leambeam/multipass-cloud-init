#!/usr/bin/env bash

set -euo pipefail

# Absolute path of directory containing the executed script
# https://stackoverflow.com/questions/39340169/dir-cd-dirname-bash-source0-pwd-how-does-that-work
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly script_dir # Declare and assign separately to avoid masking return values (shellcheck SC2155)

readonly ssh_base="${script_dir}/ssh"
readonly cloud_init_base="${script_dir}/cloud-init"

vm_not_found() {
    local vm=$1
    local answer 
    while true; do
        read -r -p "VM \"$vm\" not found on Multipass. Delete any associated local files? (y/n): " answer
        case "$answer" in
        y) return 0 ;;
        n) return 1 ;;
        *) echo "Invalid choice. Use either y or n." >&2 ;;
        esac
    done
}

delete() {
    # Cleanup steps in this function use `|| echo "..."` guardrail to report failures without
    # interrupting the script (set -e) or skipping remaining VMs/steps. Exit code stays 0.
    for vm in "$@"; do
        local vm_key_dir="${ssh_base}/${vm}"
        local generated_cloud_init_path="${cloud_init_base}/cloud-init-$vm.yaml"

        if multipass info "$vm" &>/dev/null; then
            echo "Deleting \"$vm\"..."
            multipass delete "$vm" --purge || echo "Failed to delete \"$vm\" from Multipass." >&2
        else
            vm_not_found "$vm" || continue # skip the rest of the loop if 'vm_not_found' returns 1
        fi

        ssh-keygen -R "${vm}.local" || echo "Failed to remove \"$vm\" from known hosts." >&2

        if [[ -d "$vm_key_dir" ]]; then
            echo "Removing $vm_key_dir"
            rm -r "$vm_key_dir" || echo "Failed to remove \"$vm_key_dir\"." >&2
        fi

        if [[ -f "$generated_cloud_init_path" ]]; then
            echo "Removing $generated_cloud_init_path"
            rm "$generated_cloud_init_path" || echo "Failed to remove  \"$generated_cloud_init_path\"." >&2
        fi
    done
}

if (($# < 1)); then
    echo "Usage with a single VM: $0 <vm-name>" >&2
    echo "Usage with multiple VMs: $0 <vm-name-1> <vm-name-2> <vm-name-3>" >&2
    exit 1
fi

delete "$@"