#!/usr/bin/env bash

set -euo pipefail

readonly env_file="/tmp/shared_vars.env"

if [[ ! -f $env_file ]]; then
	echo "Failed to locate the env file \"$env_file\"."
	exit 1
fi

# Ignore that the file doesn't exist at the moment of the lint
# shellcheck disable=SC1090
source "$env_file"

if [[ -n "$full_path" ]]; then
	echo "Removing $full_path"
	rm -r "$full_path"
fi

if [[ -n "$cloud_init_path" ]]; then
	echo "Removing $cloud_init_path"
	rm "$cloud_init_path"
fi

if [[ -n "$name" ]]; then
	ssh-keygen -R "${name}.local"
	multipass stop "$name"
	multipass delete "$name"
	multipass purge
fi

rm "$env_file"

