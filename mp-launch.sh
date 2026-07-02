#!/usr/bin/env bash

# set -o errexit   # abort on nonzero exitstatus
# set -o nounset   # abort on unbound variable
# set -o pipefail  # don't hide errors within pipes

set -x # debug

# Absolute path of directory containing the executed script
# https://stackoverflow.com/questions/39340169/dir-cd-dirname-bash-source0-pwd-how-does-that-work
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly script_dir # Declare and assign separately to avoid masking return values (shellcheck SC2155)

readonly vms_base="${script_dir}/vms"                                   # root directory for per-vm directories
readonly template_base="${script_dir}/templates"                        # directory for cloud-init templates
readonly cloud_init_template_path="${template_base}/cloud-init.yaml"    # path to the cloud-init template copied per VM

readonly ssh_key_type="ed25519"                                         
readonly ssh_key_name="id_ed25519"                                      

# Default values per Multipass 
# https://documentation.ubuntu.com/multipass/latest/reference/command-line-interface/launch/
# Note: Multipass (e.g., in 'multipass launch') accepts G, M, K suffixes as binary units (i.e., powers of 1024: GiB, MiB, and KiB.
# The longer GiB/MiB/KiB suffixes are also valid in Multipass but aren't included in this script's validation regex
readonly default_disk_size="5G"                                         # virtual disk
readonly default_memory_size="1G"                                       # vRAM
readonly default_ubuntu_image="26.04"                                   # VM image
readonly default_cpu_count=1                                            # vCPUs

# Custom caps
readonly disk_max_mib=40000                                             # virtual disk
readonly memory_max_mib=4000                                            # vRAM
readonly cpu_max_count=4                                                # vCPUs

# Minimal values allowed by Multipass. 'multipass launch' will fail if any of these are lowered
readonly disk_min_mib=512                                               # virtual disk
readonly memory_min_mib=128                                             # vRAM
readonly cpu_min_count=1                                                # vCPUs

# Prompts that are used for the user message in the generic ask_size() function
readonly disk_prompt_label="disk_size"
readonly memory_prompt_label="memory_allocation"

# Runtime values                
readonly random_suffix="$RANDOM"                                        # suffix used when the requested VM name is taken
vm_name=${1:-}                                                          # requested VM name; may get a random suffix if already taken

# Runtime paths
# vm_dir, private_key_path, generated_cloud_init_path, and ssh_config_path
# are declared once the final vm_name is known

die() {
  echo "${1}" >&2
  exit 1
}

# Add the generated SSH public key to the VM's generated cloud-init file
# Globals: generated_cloud_init_path, sed_flag
# Arguments: target_private_key_path
append_cloud_init() {
    local target_private_key_path=$1
    local public_key_path="${target_private_key_path}.pub"
    local public_key
    public_key=$(cat "$public_key_path")
    
    sed "${sed_flag[@]}" "1,/ssh_authorized_keys: \[.*\]/s|ssh_authorized_keys: \[.*\]|ssh_authorized_keys: [$public_key]|" "$generated_cloud_init_path"
}

# Prompt for either disk or memory size allocation
# Globals: none
# Arguments: prompt_label, default_value, max_mib, min_mib
ask_size() {
    local prompt_label=$1
    local default_value=$2
    local max_mib=$3
    local min_mib=$4
    local limits_message="(min: $min_mib, default: $default_value, max: $(( max_mib / 1000 ))G)" # Pipe through 'bc' if decimal G caps are ever needed
    local requested_size
    local requested_size_mib

    while true; do

        read -r -p "How much \"$prompt_label\" do you want to allocate $limits_message? " requested_size

        if [[ -z "$requested_size" ]]; then
            echo "$default_value"
            return
        fi
        
        # TODO: Add 'K' suffix?
        # Accept integers and decimals with 'M' and 'G' suffixes e.g., 1.5G or 15M
        if ! [[ "$requested_size" =~ ^[0-9]+([.][0-9]+)?[MG]$ ]]; then
            echo "Invalid format. Use: 1000M or 5G." >&2
            continue
        fi

        if [[ "$requested_size" == *G ]]; then
            requested_size_mib=$(echo "scale=0; ${requested_size%G} * 1000" | bc)
        else
            requested_size_mib=$(echo "${requested_size%M}" | bc)
        fi

        if (( "$requested_size_mib" > "$max_mib" )); then
            echo "Exceeds the max allowed $prompt_label $max_mib M. Try a smaller value." >&2
            continue
        fi

        if (( "$requested_size_mib" < "$min_mib" )); then
            echo "Less than min allowed $prompt_label $min_mib M. Try a larger value." >&2
            continue
        fi

        echo "$requested_size"
        return
    done
}

# Prompt for an image to use in the VM
# Globals: default_ubuntu_image
# Arguments: none
ask_image() {
    local selected_ubuntu_image
    local image_choice

    while true; do

cat <<EOF >&2 # redirect to stderr as stdout is captured by the caller: ubuntu_image=$(ask_image)
    Choose Ubuntu image:
    1) 22.04 LTS
    2) 24.04 LTS
    3) 25.10
    4) 26.04 LTS
EOF

        read -r -p "Which image do you want to use (default: $default_ubuntu_image): " image_choice
    
        case "$image_choice" in
            1) selected_ubuntu_image="22.04";;
            2) selected_ubuntu_image="24.04";;
            3) selected_ubuntu_image="25.10";;
            4) selected_ubuntu_image="26.04";;
           "") selected_ubuntu_image="$default_ubuntu_image";; # use default on empty input
            *)
                echo "Invalid choice. Enter 1, 2, 3, or 4." >&2
                continue
                ;;
        esac

        # 'multipass find' exits 0 even on failure (v1.16.3), so check output instead
        if [[ $(multipass find "$selected_ubuntu_image" --only-images) != *"No images"* ]] ; then
            echo "$selected_ubuntu_image"
            return 0
        fi

        echo "Ubuntu image \"$selected_ubuntu_image\" was not found by multipass. Choose another image." >&2
    done
}

# Prompt for a cpu allocation in the VM
# Globals: cpu_min_count, default_cpu_count, cpu_max_count
# Arguments: none
ask_cpu() {
    local requested_cpus

    while true; do

        read -r -p "How many CPUs do you want to allocate (min: $cpu_min_count, default: $default_cpu_count, max: $cpu_max_count)? " requested_cpus

        if [[ -z "$requested_cpus" ]]; then
            echo "$default_cpu_count"
            return
        fi

        if ! [[ "$requested_cpus" =~ ^[0-9]+$ ]]; then
            echo "Invalid format. Use a whole number, for example: 2." >&2
            continue
        fi

        if (( "$requested_cpus" > "$cpu_max_count" )); then
            echo "Exceeds the max allowed CPU allocation $cpu_max_count. Try a smaller value." >&2
            continue
        fi

        if (( "$requested_cpus" < "$cpu_min_count" )); then
            echo "Less than min allowed CPU allocation $cpu_min_count. Try a larger value." >&2
            continue
        fi

        echo "$requested_cpus"
        return

    done
}

# Check if all required tools are installed 
# Globals: none
# Arguments: none
check_required_tools() {
    local required_tools=("multipass" "ssh" "ssh-keygen" "ssh-keyscan" "sed" "awk" "bc")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if (( "${#missing_tools[@]}" > 0 )); then
        for tool in "${missing_tools[@]}"; do
            echo "Required tool not found: $tool" >&2
        done
        die "Missing dependencies. Install the tools listed above and try again."
    fi
}

if [[ -z "$vm_name" ]]; then
    die "Usage: $0 <vm-name>."
# Reject invalid names early to avoid orphaned local files once 'multipass launch' fails on them
# Name format per Multipass documentation: https://documentation.ubuntu.com/multipass/latest/reference/instance-name-format/
elif [[ ! $vm_name =~ ^[a-zA-Z]([a-zA-Z0-9-]*[a-zA-Z0-9])?$ ]]; then
    die "Invalid VM name \"$vm_name\": must start with a letter, end with a letter or digit, and contain only letters, digits, or hyphens in between (e.g. vm-111)."
fi

# BSD (macOS and other bsd systems) sed requires an empty backup suffix for -i, while GNU (Linux) sed does not.
# Arrays are used here as it is the safest way to store commands with arguments
case "$OSTYPE" in
    *darwin*|*bsd*) sed_flag=(-i "");;
    *linux*) sed_flag=(-i);;
    *) die "Unsupported OS type" ;;
esac
readonly sed_flag

check_required_tools

ubuntu_image=$(ask_image)
disk_size=$(ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_mib" "$disk_min_mib")
memory_size=$(ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_mib" "$memory_min_mib")
cpus=$(ask_cpu)

# Create /vms idempotently (i.e., do not fail if already exists)
mkdir -p "$vms_base"

# If the VM name or key directory is already taken, choose a shared new name.
if multipass info "$vm_name" &> /dev/null || [[ -d "${vms_base}/${vm_name}" ]]; then
    echo "VM name or key directory \"$vm_name\" already exists. Appending a random number."
    vm_name="${vm_name}-${random_suffix}"
fi

vm_dir="${vms_base}/${vm_name}"                                       # per-vm directory storing key pair, SSH config, and VM's generated cloud-init
private_key_path="${vm_dir}/${ssh_key_name}"                          # path to the private key
generated_cloud_init_path="${vm_dir}/cloud-init.yaml"                 # path to the VM's generated cloud-init file
ssh_config_path="${vm_dir}/config"                                    # path to the SSH config

mkdir "$vm_dir" || die "Failed to create directory: \"$vm_dir\"."

# Check if the template exists and copy it
if [[ -f "$cloud_init_template_path" ]]; then
    echo "Found the cloud-init template. Copying it"
    cp "$cloud_init_template_path" "$generated_cloud_init_path"
else
    die "Failed to find cloud-init template at \"$cloud_init_template_path\"."
fi

ssh-keygen -t "$ssh_key_type" -f "$private_key_path" -N "" || die "Failed to generate key pair at \"$private_key_path\"."
append_cloud_init "$private_key_path" || die "Failed to append cloud init: \"$generated_cloud_init_path\"."

# TODO: remove?
# Config file should not exist, but check just in case
if [[ ! -f "$ssh_config_path" ]]; then
cat <<EOF > "$ssh_config_path"
Host ${vm_name}
    HostName ${vm_name}.local
    IdentityFile ${private_key_path}
    User ubuntu
    Port 22
EOF
fi

# Restrict permissions on VM-related files and directory
chmod 700 "$vm_dir"
chmod 600 "$ssh_config_path"
chmod 600 "$private_key_path"
chmod 644 "${private_key_path}.pub"
chmod 644 "$generated_cloud_init_path"

multipass launch "$ubuntu_image" --name "$vm_name" --disk "$disk_size" --memory "$memory_size" --cpus "$cpus" --cloud-init "$generated_cloud_init_path"

readonly ssh_max_attempts=5

for (( ssh_attempt = 1; ssh_attempt <= ssh_max_attempts; ssh_attempt++ )); do
    # Column order per 'multipass list': Name, State, IPv4, Image. May change in future versions
    read -r current_vm_status current_vm_ip < <(multipass list | awk -v vm_name="$vm_name" '$1 == vm_name {print $2, $3}')
    if [[ "$current_vm_status" == "Running" && -n "$current_vm_ip" ]]; then
        # Uses IP instead of the hostname as 'ssh-keyscan' takes long time to fail on non-existing hostnames.
        if ssh-keyscan -T 1 "$current_vm_ip" &> /dev/null; then
            # StrictHostKeyChecking=accept-new does an automatic entry to '~/.ssh/known_hosts'
            ssh -i "$private_key_path" -o StrictHostKeyChecking=accept-new "ubuntu@$vm_name.local"
            exit 0
        fi
    fi
    sleep 3
done

die "Failed to connect to \"$vm_name\" after $ssh_max_attempts attempts."