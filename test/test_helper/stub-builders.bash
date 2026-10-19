# Reusable stub builders
# These functions emulate binaries and meant to be sourced into Bats tests

# Builds the 'images' entry of the JSON output shared by the 'multipass images' and 'multipass find' commands
_multipass_images_json() {
	local json="{}"
	local image
	for image in "$@"; do
		json=$(jq -cn --arg k "$image" --argjson o "$json" '$o + {$k: {}}')
	done
	echo "{\"images\": $json}"
}

stub_multipass_images_list() {
	stub multipass "images --format json : echo '$(_multipass_images_json "$@")'"
}

stub_multipass_find_list() {
	stub multipass "find --format json : echo '$(_multipass_images_json "$@")'"
}

stub_all_tools() {
	local required_tools=("multipass" "ssh" "ssh-keygen" "ssh-keyscan" "sed" "jq" "bc")

	for tool in "${required_tools[@]}"; do
		stub "$tool" ": echo '$tool'; exit 0"
	done
}

unstub_all_tools() {
	local required_tools=("multipass" "ssh" "ssh-keygen" "ssh-keyscan" "sed" "jq" "bc")

	for tool in "${required_tools[@]}"; do
		# 'command -v' from 'check_required_tools()' never actually executes
		# these stubs; if stub is never executed, unstub fails
		"$tool"
		unstub "$tool"
	done
}

stub_multipass_info_present() {
	local vm=$1
	stub multipass "info $vm : exit 0"
}

stub_multipass_info_missing() {
	local vm=$1
	stub multipass "info $vm : exit 1"
}

stub_multipass_delete() {
	local vm=$1
	stub multipass "delete $vm --purge : exit 0"
}

stub_multipass_delete_fail() {
	local vm=$1
	stub multipass "delete $vm --purge : exit 1"
}

stub_ssh_keygen_rm() {
	local vm=$1
	stub ssh-keygen "-R ${vm}.local : exit 0"
}

stub_ssh_keygen_rm_fail() {
	local vm=$1
	stub ssh-keygen "-R ${vm}.local : exit 1"
}
