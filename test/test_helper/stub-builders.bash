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