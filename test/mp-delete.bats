setup() {
    load 'common-setup'
    load 'test_helper/stub-builders'
    _common_setup
    bats_load_library bats-file
}

@test "test something." {
    run --separate-stderr vm_not_found vm-1111 <<< $'b\nn'
    echo "$stderr" >&3
    # echo "$vms_base_dir" >&3
    assert_not_exists /hello/world
    assert_exists /tmp
}