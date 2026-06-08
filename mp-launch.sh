#!/usr/bin/env bash

# set -o errexit   # abort on nonzero exitstatus
# set -o nounset   # abort on unbound variable
# set -o pipefail  # don't hide errors within pipes

set -x # debug

# Configuration
# path="$HOME/.ssh/keys"
readonly ssh_path="test"                            # base directory for SSH key directories
readonly cloud_init_template="cloud-init.yaml"      # path to the cloud-init template copied per VM
readonly key_type="ed25519"                         # ssh-keygen key type
readonly key_name="id_ed25519"                      # SSH private key filename

# Defaults
disk="5G"                                      # default Multipass VM disk size, can be overridden interactively
memory="1G"                                    # default Multipass VM memory size, can be overridden interactively
readonly disk_cap_mib=40000                              
readonly memory_cap_mib=4000
readonly disk_min=512                          # Minimal value allowed by Multipass
readonly memory_min=128                        # Minimal value allowed by Multipass
readonly disk_label="disk_size"
readonly memory_label="memory_allocation"

# Runtime values                
rand_num="$RANDOM"                                  # suffix used when the requested VM/key directory name is taken
name=${1:-}                                         # requested VM name; may get a random suffix if already taken

# Runtime paths
# Assigned after the final VM name is decided, so the VM, key directory,
# and generated cloud-init file all share the same name.
#
# full_path="${ssh_path}/${name}"          # SSH key directory for this VM
# key_path="${full_path}/${key_name}"      # private key path
# cloud_init_path="cloud-init-$name.yaml"  # generated cloud-init file in the current directory

die() {
  echo "${1}" >&2
  exit 1
}

# Generate SSH key pair with no passphrase
# Globals: key_type
# Arguments: key_path
generate_keys() {
    local key_path=$1
    ssh-keygen -t "$key_type" -f "$key_path" -N ""
}

# Add the generated public key to the copied cloud-init file.
# Globals: cloud_init_path
# Arguments: key_path
append_cloud_init() {
    local key_path=$1
    local pub_key_path="${key_path}.pub"
    local pub_key
    pub_key=$(cat "$pub_key_path")

    sed -i "" "1,/ssh_authorized_keys: \[.*\]/s|ssh_authorized_keys: \[.*\]|ssh_authorized_keys: [$pub_key]|" "$cloud_init_path"
}


ask_size() {
    local label=$1
    local default_value=$2
    local cap=$3
    local min=$4
    local message="(min: $min, default: $default_value, max: $(( cap / 1000 ))G)" # Pipe to "bc" if there is a need to set a decimal disk/memory cap 
    local input
    local input_mb

    while true; do

        read -r -p "How much \"$label\" do you want to allocate $message? " input

        if [[ -z "$input" ]]; then
            echo "$default_value"
            return
        fi

        if ! [[ "$input" =~ ^[0-9]+([.][0-9]+)?[MG]$ ]]; then
            echo "Invalid format. Use: 1000M or 5G." >&2
            continue
        fi

        if [[ "$input" == *G ]]; then
            input_mb=$(echo "scale=0; ${input%G} * 1000" | bc)
        else
            input_mb=$(echo "${input%M}" | bc)
        fi

        if (( "$input_mb" > "$cap" )); then
            echo "Exceeds the max allowed $label $cap M. Try a smaller value." >&2
            continue
        fi

        if (( "$input_mb" < "$min" )); then
            echo "Less than min allowed $label $min M. Try a larger value." >&2
            continue
        fi

        echo "$input"
        return
    done
}

# Check if the VM name was provided
if [[ -z "$name" ]]; then
    die "Usage: $0 <vm-name>."
fi

# Check if the SSH key base path exists
if [[ ! -d "$ssh_path" ]]; then
    die "Failed to access key base path at \"$ssh_path\"."
fi

# If the VM name or key directory is already taken, choose a shared new name.
if multipass list | awk '{print $1}' | grep -Fxq -- "$name" || [[ -d "${ssh_path}/${name}" ]]; then
    echo "VM name or key directory \"$name\" already exists. Appending a random number."
    name="${name}-${rand_num}"
fi

# TODO: Identify and export variables needed for the mp-delete script
full_path="${ssh_path}/${name}"
key_path="${full_path}/${key_name}"
cloud_init_path="cloud-init-$name.yaml"

# Check if the template exists and copy it
if [[ -f "$cloud_init_template" ]]; then
    echo "Found the cloud-init template. Copying it"
    cp "$cloud_init_template" "$cloud_init_path"
else
    die "Failed to find cloud-init template at \"$cloud_init_template\"."
fi

mkdir "$full_path" || die "Failed to create directory: \"$full_path\"."
generate_keys "$key_path" || die "Failed to generate key pair at \"$key_path\"."
append_cloud_init "$key_path" || die "Failed to append cloud init: \"$cloud_init_path\"."
 

disk=$(ask_size "$disk_label" "$disk" "$disk_cap_mib" "$disk_min")
memory=$(ask_size "$memory_label" "$memory" "$memory_cap_mib" "$memory_min")

# TODO: Add case statement with multiple Ubuntu versions
# TODO: Add logic for setting CPUs in `multipass launch`

multipass launch --name "$name" --disk "$disk" --memory "$memory" --cloud-init "$cloud_init_path"

max_attempts=5

for (( attempt = 1; attempt <= max_attempts; attempt++ )); do      
    read -r vm_status vm_ip < <(multipass list | awk -v name="$name" '$1 == name {print $2, $3}')
    if [[ "$vm_status" == "Running" && -n "$vm_ip" ]]; then
        # Uses IP instead of the hostname as `ssh-keyscan` takes long time to fail on non-existing hostnames.
        if ssh-keyscan -T 1 "$vm_ip" &> /dev/null; then
            # StrictHostKeyChecking=accept-new does an automatic entry to '~/.ssh/known_hosts'
            ssh -i "$key_path" -o StrictHostKeyChecking=accept-new "ubuntu@$name.local"
            exit 0
        fi
    fi
    sleep 3
done

die "Failed to connect to \"$name\" after $max_attempts attempts."