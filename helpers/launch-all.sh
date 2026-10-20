#!/usr/bin/env bash
#
# Launch vms with 4 currently avaliable images, choose default values for every prompt, and check the ssh connection
# To run this script, comment out the ssh retry loop at the end of main() in mp-launch.sh
# and add 'exit 0' right after the 'multipass launch' call

set -euo pipefail

vm_names=(vm-1 vm-2 vm-3 vm-4)

for i in "${!vm_names[@]}"; do
    index=$(printf '%s%s\n%s\n%s\n%s\n' $((i + 1)) "" "" "" "")
    mp-launch "${vm_names[$i]}" <<<"$index"
done

for vm in "${vm_names[@]}"; do
    if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=3 "$vm" -- true &>/dev/null; then
        echo "$vm is reachable" >&2
    else
        echo "$vm is not reachable" >&2
    fi
done
