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
    assert_output "5G"
}

# bats test_tags=ask_size, disk_space
@test "call ask_size() - 'disk space' with normal input" {
    run ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "10G"
    assert_success
    assert_output "10G"
}

# bats test_tags=ask_size, disk_space
@test "call ask_size() - 'disk space' with input exceeding disk_max_gib cap" {
    run --separate-stderr ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< $'1000G\n10G'
    assert_stderr "Exceeds the max allowed $disk_prompt_label ${disk_max_gib}G. Try a smaller value."
    assert_output "10G"
    assert_success
}

# bats test_tags=ask_size, disk_space
@test "call ask_size() - 'disk space' with input lower than disk_min_gib cap" {
    run --separate-stderr ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< $'1G\n10G'
    assert_stderr "Less than min allowed $disk_prompt_label ${disk_min_gib}G. Try a larger value."
    assert_output "10G"
    assert_success
}

# bats test_tags=ask_size, memory
@test "call ask_size() - 'memory' with no input" {
    run ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< ""
    assert_success
    assert_output "1G"
}

# bats test_tags=ask_size, memory
@test "call ask_size() - 'memory' with normal input" {
    run ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< "3G"
    assert_success
    assert_output "3G"
}

# bats test_tags=ask_size, memory
@test "call ask_size() - 'memory' with input exceeding memory_max_gib cap" {
    run --separate-stderr ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< $'1000G\n3G'
    assert_stderr "Exceeds the max allowed $memory_prompt_label ${memory_max_gib}G. Try a smaller value."
    assert_output "3G"
    assert_success
}

# bats test_tags=ask_size, memory
@test "call ask_size() - 'memory' with input lower than memory_min_gib cap" {
    run --separate-stderr ask_size "$memory_prompt_label" "$default_memory_size" "$memory_max_gib" "$memory_min_gib" <<< $'0.5G\n3G'
    assert_stderr "Less than min allowed $memory_prompt_label ${memory_min_gib}G. Try a larger value."
    assert_output "3G"
    assert_success
}

# Tests regex used for both prompts, so there is no need in duplication of this test
# bats test_tags=ask_size
@test "call ask_size() with multiple bad inputs" {
    local bad_inputs=(30 abc G30 30-G 30.0.0G .30G 30.G 30ABC -30G 30M00G)

    for input in "${bad_inputs[@]}"; do
        run --separate-stderr ask_size "$disk_prompt_label" "$default_disk_size" "$disk_max_gib" "$disk_min_gib" <<< "$input"
        assert_stderr "Invalid format: \"$input\". Use: 1000M or 5G."
    done
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