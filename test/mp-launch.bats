setup() {
    load 'common-setup'
    load 'test_helper/stub-builders'
    _common_setup
}

# bats test_tags=ask_size, disk_space
@test "ask_size() returns the default disk space on empty input" {
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< ""
    assert_success
    assert_output "$default_disk_size"
}

# bats test_tags=ask_size, disk_space
@test "ask_size() accepts normal disk space input in GiB" {
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "5G"
    assert_success
    assert_output "5G"
}

# bats test_tags=ask_size, disk_space
@test "ask_size() accepts normal disk space input in MiB" {
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "5120M"
    assert_success
    assert_output "5120M"
}

# bats test_tags=ask_size, disk_space
@test "ask_size() accepts decimal disk space input" {
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "5.5G"
    assert_success
    assert_output "5.5G"
}

# bats test_tags=ask_size, disk_space
@test "ask_size() re-prompts when disk space input exceeds the max allowed cap" {
    run --separate-stderr ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< $'1000G\n5G'
    assert_stderr "Exceeds the max allowed $disk_prompt_label ${disk_max_gib}G. Try a smaller value."
    assert_success
    assert_output "5G"
}

# bats test_tags=ask_size, disk_space
@test "ask_size() accepts disk space input exactly at the max allowed cap" {
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${disk_max_gib}G"
    assert_success
    assert_output "${disk_max_gib}G"
}

# bats test_tags=ask_size, disk_space
@test "ask_size() re-prompts when disk space input is lower than the min allowed cap" {
    run --separate-stderr ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< $'1G\n10G'
    assert_stderr "Less than min allowed $disk_prompt_label ${disk_min_gib}G. Try a larger value."
    assert_success
    assert_output "10G"
}

# bats test_tags=ask_size, disk_space
@test "ask_size() accepts disk space input exactly at the min allowed cap" {
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${disk_min_gib}G"
    assert_success
    assert_output "${disk_min_gib}G"
}

# bats test_tags=ask_size, memory
@test "ask_size() returns the default memory on empty input" {
    run ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< ""
    assert_success
    assert_output "$default_memory_size"
}

# bats test_tags=ask_size, memory
@test "ask_size() re-prompts when memory input is lower than the min allowed cap" {
    run --separate-stderr ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< $'0.5G\n2G'
    assert_stderr "Less than min allowed $memory_prompt_label ${memory_min_gib}G. Try a larger value."
    assert_success
    assert_output "2G"
}

# Tests regex used for both 'disk space' and 'memory' arguments, so there is no need in duplication of this test
# bats test_tags=ask_size, misc
@test "ask_size() rejects multiple invalid disk space input formats" {
    local invalid_inputs=(30 abc G30 30-G 30.0.0G .30G 30.G 30ABC -30G 30M00G)

    for input in "${invalid_inputs[@]}"; do
        run --separate-stderr ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "$input"
        assert_stderr "Invalid format: \"$input\". Use: 1000M or 5G."
    done
}

# MiB-to-GiB conversion precision tests (scale=10 in bc division).
# These aren't testing disk/memory bound values, so there is no need to duplicate for 'memory' param.
# bats test_tags=ask_size, misc
@test "ask_size() accepts MiB disk space input at the edge of the max allowed cap" {
    local edge_mib
    edge_mib=$(echo "$disk_max_gib * 1024" | bc)
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${edge_mib}M"
    assert_success
    assert_output "${edge_mib}M"
}

# bats test_tags=ask_size, misc
@test "ask_size() accepts MiB disk space input at the edge of the min allowed cap" {
    local edge_mib
    edge_mib=$(echo "$disk_min_gib * 1024" | bc)
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${edge_mib}M"
    assert_success
    assert_output "${edge_mib}M"
}

# bats test_tags=ask_size, misc
@test "ask_size() rejects MiB disk space input just over the max allowed cap" {
    local over_max_mib
    over_max_mib=$(echo "$disk_max_gib * 1024 + 1" | bc)
    run --separate-stderr ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${over_max_mib}M"
    assert_stderr "Exceeds the max allowed $disk_prompt_label ${disk_max_gib}G. Try a smaller value."
}

# bats test_tags=ask_size, misc
@test "ask_size() rejects MiB disk space input just under the min allowed cap" {
    local under_min_mib
    under_min_mib=$(echo "$disk_min_gib * 1024 - 1" | bc)
    run --separate-stderr ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${under_min_mib}M"
    assert_stderr "Less than min allowed $disk_prompt_label ${disk_min_gib}G. Try a larger value."
}

# bats test_tags=ask_cpu
@test "ask_cpu() returns the default CPU count on empty input" {
    run ask_cpu <<< ""
    assert_success
    assert_output "$default_cpu_count"
}

# bats test_tags=ask_cpu
@test "ask_cpu() rejects multiple invalid CPU count input formats" {
    local invalid_inputs=(-1 1.5 1.0 0.5 1G 1M abc 1a2 a1a)

    for input in "${invalid_inputs[@]}"; do
        run --separate-stderr ask_cpu <<< "$input"
        assert_stderr "Invalid format: \"$input\" Use a whole number (e.g. 2)."
    done
}

# bats test_tags=ask_cpu
@test "ask_cpu() rejects CPU count input exceeding the max allowed cap" {
    run --separate-stderr ask_cpu <<< 10
    assert_stderr "Exceeds the max allowed CPU allocation $cpu_max_count. Try a smaller value."
}

# bats test_tags=ask_cpu
@test "ask_cpu() rejects CPU count input lower than the min allowed cap" {
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

# bats test_tags=ask_image
@test "ask_image() returns the correct image for each valid menu choice" {
    local ubuntu_images=("22.04" "24.04" "25.10" "26.04")
    local counter=0
    for image in "${ubuntu_images[@]}"; do
        counter=$((counter+1))
        stub_multipass_find_present "$image"
        run --separate-stderr ask_image <<< "$counter"
        assert_success
        assert_output "$image"
        unstub multipass
    done
}

# bats test_tags=ask_image
@test "ask_image() re-prompts when multipass reports no matching image" {
    stub_multipass_find_missing "22.04"
    stub_multipass_find_present "24.04"

    run --separate-stderr ask_image <<< $'1\n2'
    assert_stderr_line 'Multipass could not find Ubuntu image "22.04". Choose another image.'
    assert_success
    assert_output "24.04"
    unstub multipass
}

# bats test_tags=ask_image
@test "ask_image() re-prompts with a warning on an invalid menu choice" {
    stub_multipass_find_present "22.04"

    run --separate-stderr ask_image <<< $'9\n1'
    assert_stderr_line 'Invalid choice: "9". Enter 1, 2, 3, or 4.'
    assert_success
    assert_output "22.04"
    unstub multipass
}

# bats test_tags=ask_image
@test "ask_image() returns the default image on empty input" {
    stub_multipass_find_present "$default_ubuntu_image"

    run --separate-stderr ask_image <<< ""
    assert_success
    assert_output "$default_ubuntu_image"
    unstub multipass
}

# bats test_tags=check_required_tools
@test "check_required_tools() reports all missing tools and dies" {
    local required_tools=("multipass" "ssh" "ssh-keygen" "ssh-keyscan" "sed" "jq" "bc")
    # Not using --separate-stderr here: PATH is intentionally set to
    # $BATS_MOCK_BINDIR (only for the duration of 'run' execution),
    # which has no 'mktemp', so stdout/stderr splitting isn't available
    PATH="$BATS_MOCK_BINDIR" run check_required_tools

    for tool in "${required_tools[@]}"; do
        assert_line "Required tool not found: $tool"
    done
    assert_line "Missing dependencies. Install the tools listed above and try again."
    assert_failure
}

# bats test_tags=check_required_tools
@test "check_required_tools() passes with all the tools present" {
    stub_all_tools
    run --separate-stderr check_required_tools
    assert_success
    unstub_all_tools
}

# bats test_tags=main
@test "main() returns usage message and dies on invocation with no argument" {
    run --separate-stderr mp-launch.sh
    assert_stderr --partial 'Usage:'
    assert_stderr --partial '<vm-name>.'
    assert_failure
}

# bats test_tags=main
@test "main() returns an error and dies on an invalid vm name" {
    local invalid_inputs=("1vm" "vm-" "v!m*" ",./" "-" "1")

    for input in "${invalid_inputs[@]}"; do
        run --separate-stderr mp-launch.sh "$input"
        assert_stderr "Invalid VM name \"$input\": must start with a letter, end with a letter or digit, and contain only letters, digits, or hyphens in between (e.g. vm-111)."
        assert_failure
    done
}