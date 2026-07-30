setup() {
    load 'common-setup'
    _common_setup
}

@test "prints usage message on invocation with no arguments" {
    skip
    run mp-launch.sh
    assert_output "Usage: mp-launch.sh <vm-name>."
}

# bats test_tags=ask_size, disk_space
@test "call ask_size() - 'disk space' with no input" {
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< ""
    assert_success
    assert_output "$default_disk_size"
}

# bats test_tags=ask_size, disk_space
@test "call ask_size() - 'disk space' with normal input in GiB" {
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "5G"
    assert_success
    assert_output "5G"
}

# bats test_tags=ask_size, disk_space
@test "call ask_size() - 'disk space' with normal input in MiB" {
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "5120M"
    assert_success
    assert_output "5120M"
}

# bats test_tags=ask_size, disk_space
@test "call ask_size() - 'disk space' with decimal input" {
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "5.5G"
    assert_success
    assert_output "5.5G"
}

# bats test_tags=ask_size, disk_space
@test "call ask_size() - 'disk space' with input exceeding 'disk_max_gib' cap" {
    run --separate-stderr ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< $'1000G\n5G'
    assert_stderr "Exceeds the max allowed $disk_prompt_label ${disk_max_gib}G. Try a smaller value."
    assert_output "5G"
    assert_success
}

# bats test_tags=ask_size, disk_space
@test "call ask_size() - 'disk space' accepts exactly 'disk_max_gib'" {
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${disk_max_gib}G"
    assert_success
    assert_output "${disk_max_gib}G"
}

# bats test_tags=ask_size, disk_space
@test "call ask_size() - 'disk space' with input lower than 'disk_min_gib' cap" {
    run --separate-stderr ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< $'1G\n10G'
    assert_stderr "Less than min allowed $disk_prompt_label ${disk_min_gib}G. Try a larger value."
    assert_output "10G"
    assert_success
}

# bats test_tags=ask_size, disk_space
@test "call ask_size() - 'disk space' accepts exactly 'disk_min_gib'" {
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${disk_min_gib}G"
    assert_success
    assert_output "${disk_min_gib}G"
}

# bats test_tags=ask_size, memory
@test "call ask_size() - 'memory' with no input" {
    run ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< ""
    assert_success
    assert_output "$default_memory_size"
}

# bats test_tags=ask_size, memory
@test "call ask_size() - 'memory' with normal input in GiB" {
    run ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< "2G"
    assert_success
    assert_output "2G"
}

# bats test_tags=ask_size, memory
@test "call ask_size() - 'memory' with normal input in MiB" {
    run ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< "2048M"
    assert_success
    assert_output "2048M"
}

# bats test_tags=ask_size, memory
@test "call ask_size() - 'memory' with decimal input" {
    run ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< "2.5G"
    assert_success
    assert_output "2.5G"
}

# bats test_tags=ask_size, memory
@test "call ask_size() - 'memory' with input exceeding 'memory_max_gib' cap" {
    run --separate-stderr ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< $'1000G\n2G'
    assert_stderr "Exceeds the max allowed $memory_prompt_label ${memory_max_gib}G. Try a smaller value."
    assert_output "2G"
    assert_success
}

# bats test_tags=ask_size, memory
@test "call ask_size() - 'memory' accepts exactly 'memory_max_gib'" {
    run ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< "${memory_max_gib}G"
    assert_success
    assert_output "${memory_max_gib}G"
}

# bats test_tags=ask_size, memory
@test "call ask_size() - 'memory' with input lower than 'memory_min_gib' cap" {
    run --separate-stderr ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< $'0.5G\n2G'
    assert_stderr "Less than min allowed $memory_prompt_label ${memory_min_gib}G. Try a larger value."
    assert_output "2G"
    assert_success
}

# bats test_tags=ask_size, memory
@test "call ask_size() - 'memory' accepts exactly 'memory_min_gib'" {
    run ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< "${memory_min_gib}G"
    assert_success
    assert_output "${memory_min_gib}G"
}

# Tests regex used for both 'disk space' and 'memory' arguments, so there is no need in duplication of this test
# bats test_tags=ask_size, misc
@test "call ask_size() - 'disk space' with multiple bad inputs" {
    local bad_inputs=(30 abc G30 30-G 30.0.0G .30G 30.G 30ABC -30G 30M00G)

    for input in "${bad_inputs[@]}"; do
        run --separate-stderr ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "$input"
        assert_stderr "Invalid format: \"$input\". Use: 1000M or 5G."
    done
}

# MiB-to-GiB conversion precision tests (scale=10 in bc division).
# These aren't testing disk/memory bound values, so there is no need to duplicate for 'memory' param.
# bats test_tags=ask_size, misc
@test "call ask_size() - 'disk space' MiB input at the edge of 'disk_max_gib'" {
    local edge_mib
    edge_mib=$(echo "$disk_max_gib * 1024" | bc)
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${edge_mib}M"
    assert_success
    assert_output "${edge_mib}M"
}

# bats test_tags=ask_size, misc
@test "call ask_size() - 'disk space' MiB input at the edge of 'disk_min_gib'" {
    local edge_mib
    edge_mib=$(echo "$disk_min_gib * 1024" | bc)
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${edge_mib}M"
    assert_success
    assert_output "${edge_mib}M"
}

# bats test_tags=ask_size, misc
@test "call ask_size() - 'disk space' MiB input just over 'disk_max_gib' is rejected" {
    local over_max_mib
    over_max_mib=$(echo "$disk_max_gib * 1024 + 1" | bc)
    run --separate-stderr ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${over_max_mib}M"
    assert_stderr "Exceeds the max allowed $disk_prompt_label ${disk_max_gib}G. Try a smaller value."
}

# bats test_tags=ask_size, misc
@test "call ask_size() - 'disk space' MiB input just under 'disk_min_gib' is rejected" {
    local under_min_mib
    under_min_mib=$(echo "$disk_min_gib * 1024 - 1" | bc)
    run --separate-stderr ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${under_min_mib}M"
    assert_stderr "Less than min allowed $disk_prompt_label ${disk_min_gib}G. Try a larger value."
}

# bats test_tags=ask_cpu
@test "call ask_cpu() with no input" {
    run ask_cpu <<< ""
    assert_success
    assert_output "$default_cpu_count"
}

# bats test_tags=ask_cpu
@test "call ask_cpu() with multiple bad inputs" {
    local bad_inputs=(-1 1.5 1.0 0.5 1G 1M abc 1a2 a1a)

    for input in "${bad_inputs[@]}"; do
        run --separate-stderr ask_cpu <<< "$input"
        assert_stderr "Invalid format: \"$input\" Use a whole number (e.g. 2)."
    done
}

# bats test_tags=ask_cpu
@test "call ask_cpu() with input exceeding 'cpu_max_count' cap" {
    run --separate-stderr ask_cpu <<< 10
    assert_stderr "Exceeds the max allowed CPU allocation $cpu_max_count. Try a smaller value."
}

# bats test_tags=ask_cpu
@test "call ask_cpu() with input lower than 'cpu_min_count' cap" {
    run --separate-stderr ask_cpu <<< 0
    assert_stderr "Less than min allowed CPU allocation $cpu_min_count. Try a larger value."
}

# bats test_tags=append_cloud_init
@test "append_cloud_init() inserts public key into cloud-init template copy" {
    # Shadowing the global var used by 'append_cloud_init()' to provide a different path
    local generated_cloud_init_path="${BATS_FILE_TMPDIR}/cloud-init.yaml"
    local private_key_path="${BATS_FILE_TMPDIR}/test_key"
    local public_key

    cp "${PROJECT_ROOT}/templates/cloud-init.yaml" "$generated_cloud_init_path"

    case "$OSTYPE" in
        *darwin*|*bsd*) sed_flag=(-i "");;
        *linux*) sed_flag=(-i);;
        *) die "Unsupported OS type";;
    esac

    ssh-keygen -t "$ssh_key_type" -f "$private_key_path" -N "" -q
    run append_cloud_init "$private_key_path"
    assert_success

    public_key=$(cat "${private_key_path}.pub")
    run grep -Fq "ssh_authorized_keys: [$public_key]" "$generated_cloud_init_path"
    assert_success
}