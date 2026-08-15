setup() {
    load 'common-setup'
    load 'test_helper/stub-builders'
    _common_setup
    bats_load_library bats-file
}

create_vm_dir(){
    for vm in "$@"; do
        mkdir -p "${BATS_TEST_TMPDIR}/vms/${vm}"
    done
}

# bats test_tags=vm_not_found
@test "vm_not_found() re-prompts on an invalid menu choice" {
    run --separate-stderr vm_not_found vm-111 <<< $'hello\nn'
    assert_failure
    assert_stderr "Invalid choice. Use either y or n."
}

# bats test_tags=delete
@test "delete() removes one vm and its directory" {
    local vm_name="vm-111"
    local vms_base_dir="${BATS_TEST_TMPDIR}/vms"
    local vm_dir="${vms_base_dir}/${vm_name}"

    create_vm_dir "$vm_name"
    assert_exists "$vm_dir"

    stub_multipass_info_present "$vm_name"
    stub_multipass_delete "$vm_name"
    stub_ssh_keygen_rm "$vm_name"

    run --separate-stderr delete "$vm_name"
    assert_success
    refute_stderr
    assert_line "Deleting \"$vm_name\"..."
    assert_line "Removing \"$vm_dir\"..."
    assert_not_exists "$vm_dir"

    unstub multipass
    unstub ssh-keygen
}

# bats test_tags=delete
@test "delete() removes multiple vms and their directories" {
    local vm_names=("vm-111" "vm-222" "vm-333")
    local vms_base_dir="${BATS_TEST_TMPDIR}/vms"

    create_vm_dir "${vm_names[@]}"

    for vm in "${vm_names[@]}"; do
        assert_exists "${vms_base_dir}/${vm}"
        stub_multipass_info_present "$vm"
        stub_multipass_delete "$vm"
        stub_ssh_keygen_rm "$vm"
    done

    run --separate-stderr delete "${vm_names[@]}"
    assert_success
    refute_stderr

    for vm in "${vm_names[@]}"; do
        assert_line "Deleting \"$vm\"..."
        assert_line "Removing \"${vms_base_dir}/${vm}\"..."
        assert_not_exists "${vms_base_dir}/${vm}"
    done

    unstub multipass
    unstub ssh-keygen
}

# bats test_tags=delete
@test "delete() removes directory when no vm is found and vm_not_found() receives 'y' input" {
    local vm_name="vm-111"
    local vms_base_dir="${BATS_TEST_TMPDIR}/vms"
    local vm_dir="${vms_base_dir}/${vm_name}"

    create_vm_dir "$vm_name"
    assert_exists "$vm_dir"

    stub_multipass_info_missing "$vm_name"
    stub_ssh_keygen_rm "$vm_name"

    run --separate-stderr delete "$vm_name" <<< 'y'
    assert_success
    refute_stderr
    refute_line "Deleting \"$vm_name\"..."
    assert_line "Removing \"$vm_dir\"..."
    assert_not_exists "$vm_dir"

    unstub multipass
    unstub ssh-keygen
}

# bats test_tags=delete
@test "delete() keeps directory when no vm is found and vm_not_found() receives 'n' input" {
    local vm_name="vm-111"
    local vms_base_dir="${BATS_TEST_TMPDIR}/vms"
    local vm_dir="${vms_base_dir}/${vm_name}"

    create_vm_dir "$vm_name"
    assert_exists "$vm_dir"

    stub_multipass_info_missing "$vm_name"

    run --separate-stderr delete "$vm_name" <<< 'n'
    assert_success
    assert_exists "$vm_dir"
    refute_stderr
    refute_output

    unstub multipass
}

# bats test_tags=delete
@test "delete() continues cleanup when 'multipass delete' fails" {
    local vm_name="vm-111"
    local vms_base_dir="${BATS_TEST_TMPDIR}/vms"
    local vm_dir="${vms_base_dir}/${vm_name}"

    create_vm_dir "$vm_name"
    assert_exists "$vm_dir"

    stub_multipass_info_present "$vm_name"
    stub_multipass_delete_fail "$vm_name"
    stub_ssh_keygen_rm "$vm_name"

    run --separate-stderr delete "$vm_name"
    assert_success
    assert_stderr "Failed to delete \"$vm_name\" from Multipass."
    assert_line "Deleting \"$vm_name\"..."
    assert_line "Removing \"$vm_dir\"..."
    assert_not_exists "$vm_dir"

    unstub multipass
    unstub ssh-keygen
}

# bats test_tags=delete
@test "delete() continues cleanup when 'ssh-keygen -R' fails" {
    local vm_name="vm-111"
    local vms_base_dir="${BATS_TEST_TMPDIR}/vms"
    local vm_dir="${vms_base_dir}/${vm_name}"

    create_vm_dir "$vm_name"
    assert_exists "$vm_dir"

    stub_multipass_info_present "$vm_name"
    stub_multipass_delete "$vm_name"
    stub_ssh_keygen_rm_fail "$vm_name"

    run --separate-stderr delete "$vm_name"
    assert_success
    assert_stderr "Failed to remove \"$vm_name\" from known hosts."
    assert_line "Deleting \"$vm_name\"..."
    assert_line "Removing \"$vm_dir\"..."
    assert_not_exists "$vm_dir"

    unstub multipass
    unstub ssh-keygen
}

# bats test_tags=usage
@test "mp-delete.sh dies with a usage message when invoked with no arguments" {
    run --separate-stderr mp-delete.sh
    assert_failure
    # '/' doesn't need to be escaped in character classes
    assert_stderr_line --regexp "^Usage with a single VM: [[:alnum:]/_.-]+ <vm-name>$"
    assert_stderr_line --regexp "^Usage with multiple VMs: [[:alnum:]/_.-]+ <vm-name-1> <vm-name-2> <vm-name-3>$"
}