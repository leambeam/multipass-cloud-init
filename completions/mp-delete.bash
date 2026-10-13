_mp_delete() {
	local cur="${COMP_WORDS[COMP_CWORD]}"
	local script_dir vms_dir name
	local -a candidates=()

	# Resolve the symlink
	script_dir="$(dirname "$(readlink -f "$(command -v mp-delete)")")"
	vms_dir="${script_dir}/vms"

	# Local dirs under vms/ (covers VMs purged from multipass but have leftover configs)
	for name in "${vms_dir}"/*; do
		[[ -d "$name" ]] || continue
		candidates+=("${name##*/}")
	done

	# VMs running in multipass (may have no local dir)
	if command -v multipass &>/dev/null; then
		while IFS= read -r name; do
			[[ -n "$name" ]] && candidates+=("$name")
		done < <(multipass list --format csv 2>/dev/null | awk -F, 'NR>1 {print $1}')
	fi

	# Dedupe + prefix-match, drop names already typed on the line
	local -a used=("${COMP_WORDS[@]:1:COMP_CWORD-1}")
	local -a reply=()
	local candidate
	while IFS= read -r candidate; do
		[[ " ${used[*]} " == *" $candidate "* ]] && continue
		reply+=("$candidate")
	done < <(compgen -W "${candidates[*]}" -- "$cur" | sort -u)

	COMPREPLY=("${reply[@]}")
}

complete -F _mp_delete mp-delete
