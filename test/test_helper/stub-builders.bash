# Reusable stub builders
# These functions emulate binaries and meant to be sourced into Bats tests

stub_multipass_find_present(){
    local image=$1
    stub multipass "find ${image} --only-images : echo '$image'; exit 0"
}

stub_multipass_find_missing(){
    local image=$1
    stub multipass "find ${image} --only-images : echo 'No images found.'; exit 0"
}

stub_all_tools(){
    local required_tools=("multipass" "ssh" "ssh-keygen" "ssh-keyscan" "sed" "jq" "bc")

    for tool in "${required_tools[@]}"; do
        stub "$tool" ": echo '$tool'; exit 0"
    done
}

unstub_all_tools(){
    local required_tools=("multipass" "ssh" "ssh-keygen" "ssh-keyscan" "sed" "jq" "bc")

    for tool in "${required_tools[@]}"; do
        # 'command -v' from 'check_required_tools()' never actually executes
        # these stubs; if stub is never executed, unstub fails
        "$tool"
        unstub "$tool"
    done
}