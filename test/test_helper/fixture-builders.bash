# Reusable fixture builders
# These functions create test fixtures and are meant to be sourced into Bats tests

create_templates() {
	local dir=$1
	shift
	mkdir -p "$dir"
	local name
	for name in "$@"; do
		touch "${dir}/${name}"
	done
}
