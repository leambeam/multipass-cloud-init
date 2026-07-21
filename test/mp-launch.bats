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

# Tests MiB-to-GiB conversion precision at a highest boundary. Shared logic, no need in duplication
# bats test_tags=ask_size, misc
@test "call ask_size() - 'disk space' MiB input at the edge of 'disk_max_gib'" {
    local edge_mib
    edge_mib=$(echo "$disk_max_gib * 1024" | bc)
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${edge_mib}M"
    assert_success
    assert_output "${edge_mib}M"
}

# Tests MiB-to-GiB conversion precision at a lowest boundary. Shared logic, no need in duplication
# bats test_tags=ask_size, misc
@test "call ask_size() - 'disk space' MiB input at the edge of 'disk_min_gib'" {
    local edge_mib
    edge_mib=$(echo "$disk_min_gib * 1024" | bc)
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "${edge_mib}M"
    assert_success
    assert_output "${edge_mib}M"
}

# @test "ask_size prints correct prompt for memory" {
#     run --separate-stderr ask_size "memory" "1G" 4 1 <<< "" /dev/null
#     assert_stderr 'How much memory do you want to allocate (min: 1G, default: 1G, max: 4G)?'
#     assert_output '1G'
# }

# @test "check global vars" {
#     assert_equal "$default_disk_size" "5G"
#     assert_equal "$default_memory_size" "1G"
#     assert_equal "$disk_max_gib" "40"
#     assert_equal "$memory_max_gib" "4"
#     assert_equal "$disk_min_gib" "4"
#     assert_equal "$disk_prompt_label" "disk space"
#     assert_equal "$memory_prompt_label" "memory"
#     assert_equal "$cpu_min_count" "1"

# }