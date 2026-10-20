# multipass-cloud-init

A wrapper around Multipass that launches and destroys VMs from [cloud-init](https://cloudinit.readthedocs.io/) templates, with per-VM SSH keys and ssh config entries generated automatically. Each VM gets an alias you can use with `ssh`, `scp`, and `rsync` without per-host configuration, and it works with VS Code [Remote Development using SSH](https://code.visualstudio.com/docs/remote/ssh) out of the box.

## Why a wrapper?

The goal is to simplify remote access. Instead of remembering the full `multipass launch` invocation (image, disk, memory, CPUs, cloud-init file), the script prompts for each value, validates it, waits for the VM to come up, and enters an SSH session on the new VM.

Built-in Multipass commands keep working unchanged: `multipass shell`, `multipass exec`, and `multipass transfer` (the `scp` equivalent). One limitation of this wrapper: `multipass delete --purge` alone leaves behind the local files under `vms/` and the host entry in `~/.ssh/known_hosts`. `mp-delete.sh` handles the full cleanup: it purges the VM from Multipass, removes its host entries via `ssh-keygen -R`, and deletes its local directory under `vms/`.

## Why generate a per-VM SSH key pair, and why plain `ssh` at all?

Multipass injects its own key into every VM, but it is stored at a root-owned path (on macOS: `/var/root/Library/Application Support/multipassd/ssh-keys/id_rsa`, on Linux: `/var/snap/multipass/common/data/multipassd/ssh-keys/id_rsa`), so anything outside Multipass's own commands needs `sudo` and a quoted path to the key (for example, `sudo ssh -i "<key-path>" ubuntu@<ip>`), or you'd have to write an ssh config by hand. Generating a fresh key into the project directory at launch time avoids all of that.

## Requirements

**Note:** The scripts are not POSIX compliant.
The scripts target macOS and Linux. Windows is not supported.

1. [Install Multipass](https://canonical.com/multipass/install)

2. The scripts use a few CLI tools in addition to Multipass. Most of these ship by default on common distros. If any are missing, the script stops and tells you which ones to install:

    * `ssh`
    * `ssh-keygen`
    * `ssh-keyscan`
    * `sed`
    * `jq`
    * `bc`

3. Bash 4.3 or newer. The scripts use `mapfile` (bash 4.0) and `[[ -v "arr[i]" ]]` (bash 4.3). [macOS ships 3.2.57](https://stackoverflow.com/questions/77052638/changing-default-shell-from-zsh-to-bash-on-macos-catalina-and-beyond), which is quite old. Install a newer bash (e.g., `brew install bash`) and make sure it comes before `/bin/bash` on your `PATH`, since the first match in `PATH` is what gets executed when you call `bash`.

## Installation with symlinks (recommended)

Symlinks let you invoke the launch and delete scripts from anywhere in the terminal as you would any other command.

1. Make directories for storing the whole project and for storing symlinks to the scripts:

   **Note:** [Snap doesn't have access to hidden directories](https://documentation.ubuntu.com/security/security-features/privilege-restriction/snap-confinement/#interface-connections), so use a non-hidden directory on Linux (e.g., `~/scripts`). These instructions use `~/scripts` throughout. On macOS, if you prefer a hidden directory such as `~/.scripts`, replace every `~/scripts` reference in these instructions with `~/.scripts`.

   ```bash
   mkdir -p ~/scripts ~/.local/bin
   ```

2. Add `~/.local/bin` to your `PATH`. You can do this in any shell config file, but `.profile` (bash) or `.zprofile` (zsh) are recommended. Some distros already include this path in their config files, so you may just need to `source` the config file.

3. Clone this repo to the `~/scripts` dir:

   ```bash
   git clone https://github.com/leambeam/multipass-cloud-init.git ~/scripts/multipass-cloud-init
   ```

4. Create symlinks:

   ```bash
   ln -s ~/scripts/multipass-cloud-init/mp-launch.sh ~/.local/bin/mp-launch
   ln -s ~/scripts/multipass-cloud-init/mp-delete.sh ~/.local/bin/mp-delete
   ```

5. Add an [Include directive](https://man.openbsd.org/ssh_config#Include) to your main `~/.ssh/config` so ssh reads the per-VM configs (otherwise you would have to pass `-F <file>` on every command):

   ```text
   Include ~/scripts/multipass-cloud-init/vms/*/config
   ```

Alternatively, clone the repo and run `mp-launch.sh` and `mp-delete.sh` from the project root, or invoke them from elsewhere by relative or absolute path. VM files remain in the project directory regardless of where you run the scripts.

```bash
./mp-launch.sh my-vm
bash mp-launch.sh my-vm
```

## Usage

Launch a VM by passing its name as the only argument:

```bash
mp-launch <name>
```

The name must start with a letter, end with a letter or digit, and contain only letters, digits, and hyphens in between (e.g., `vm-111`). If the name or its directory under `vms/` is already taken, a random suffix is appended instead of failing.

Each VM's generated files are stored in `vms/<name>/`: a copy of the cloud-init template with the public key injected, an SSH config, and its private and public SSH keys.

`mp-launch.sh` prompts for the Ubuntu image, disk, memory, and CPU count. It prompts for a template only if more than one is available. Defaults and resource limits are listed in [Settings](#settings). Press Enter to accept a displayed default.

Disk and memory values accept whole or decimal numbers followed by `M` or `G`, such as `1000M` or `5.5G`.

Delete one or more VMs by passing their names:

```bash
mp-delete <name-1> <name-2> <name-3>
```

`mp-delete.sh` asks for confirmation before deleting. If a VM isn't found on Multipass, it asks whether to delete that VM's associated local files too.

## Tab completion for `mp-delete` (symlink installation only)

These instructions assume you created the `mp-delete` symlink above and that it is on your `PATH`.

Both completion scripts suggest VMs known to Multipass and orphaned VM directories.

**Note:** Both completion scripts use `awk` to parse the `multipass list` output, so tab completion requires `awk`.

### Zsh

1. Create a directory to store custom autocompletions:

   ```bash
   mkdir -p ~/.config/zsh/completions/
   ```

   Alternatively, if you use `Oh My Zsh`, you can store the completion file in `~/.oh-my-zsh/custom/completions`. This directory is already on [`$fpath`](https://zsh.sourceforge.io/Doc/Release/Parameters.html#index-fpath).

2. Copy the autocomplete file into your completions directory. If you use the `Oh My Zsh` directory, change the destination in this command to that directory:

   ```bash
   cp ~/scripts/multipass-cloud-init/completions/_mp_delete ~/.config/zsh/completions/_mp_delete
   ```

   **Note:** If you use the `Oh My Zsh` directory, skip steps 3 and 4. The `Oh My Zsh` startup script runs `compinit`, so you do not need a separate `compinit` line in `.zshrc`.

3. Add the following to `~/.zshrc` to include the `completions` directory in the `$fpath`:

   **Note:** `fpath` is an **array**. `typeset -gU fpath` removes duplicates.

   ```bash
   fpath=(~/.config/zsh/completions $fpath)
   typeset -gU fpath
   ```

4. If you do not yet have it, add the `autoload` and `compinit` lines:

   ```bash
   autoload -Uz compinit; compinit
   ```

5. Source `~/.zshrc`, check the `$fpath`, and test the autocomplete:

   ```bash
   source ~/.zshrc
   ```

   ```bash
   echo $fpath | grep -o ".config/zsh/completions"
   ```

   ```bash
   mp-delete <TAB>
   ```

### Bash

You need to have [bash-completion](https://github.com/scop/bash-completion#installation) installed and enabled.

1. Create a directory to store custom autocompletions:

   ```bash
   mkdir -p ~/.local/share/bash-completion/completions/
   ```

2. Copy the autocomplete file into your completions directory:

   ```bash
   cp ~/scripts/multipass-cloud-init/completions/mp-delete.bash ~/.local/share/bash-completion/completions/mp-delete.bash
   ```

3. Either open a new terminal or source the completion script directly into the current shell:

   ```bash
   source ~/.local/share/bash-completion/completions/mp-delete.bash
   ```

   ```bash
   mp-delete <TAB>
   ```

Alternatively, add this line to `~/.bashrc` to load the completion in each new interactive Bash session:

```bash
source ~/scripts/multipass-cloud-init/completions/mp-delete.bash
```

## Uninstall

* Removing the wrapper does not remove VMs from Multipass. If you no longer need them, delete them first:

   ```bash
   mp-delete <name>
   ```

* Then remove the symlinks and the repo:

   ```bash
   rm ~/.local/bin/mp-launch ~/.local/bin/mp-delete
   rm -rf ~/scripts/multipass-cloud-init
   ```

* If you added the `Include` line to `~/.ssh/config`, remove that line too so it doesn't point at the deleted path.

* If you set up tab completion, undo only the changes you made for it: remove the completion file you copied (`~/.config/zsh/completions/_mp_delete`, `~/.oh-my-zsh/custom/completions/_mp_delete`, or `~/.local/share/bash-completion/completions/mp-delete.bash`) and remove the related lines you added to `~/.zshrc` or `~/.bashrc`. Do not remove pre-existing settings or shared completion setup that other completions use.

* [Uninstall Multipass](https://canonical.com/multipass/docs/latest/how-to-guides/install-multipass/#uninstall) if you no longer need it.

## Custom cloud-init templates

The launch script auto-discovers every `.yaml` and `.yml` file in `templates/`. The easiest way to make a custom template is to copy the existing one and add your configs on top of it:

```bash
cp templates/cloud-init.yaml templates/my-template.yaml
```

Keep all content from the copied file. Do not remove or change it. You can edit the commented-out lines. Add your own configs on top:

* the `users` block for `ubuntu`, including its `ssh_authorized_keys: []` line. The script replaces the first `ssh_authorized_keys` line in the file with the generated public key. Keep `ubuntu` first in the file, before any other `users` blocks, or the key lands in the wrong account.
* the `avahi-daemon` package and its `systemctl enable --now` line. The script connects to `<name>.local` and writes that name into the ssh config, so mDNS must be running on the VM. Without it, the connection fails.

See the [cloud-init docs](https://cloudinit.readthedocs.io/) for the full range of directives you can add.

## Settings

To customize launch behavior, edit the `readonly` variables at the top of `mp-launch.sh`. The table lists their current values.

| Variable | Value | Meaning |
| --- | --- | --- |
| `default_ubuntu_image` | `26.04` | default answer for the image prompt |
| `default_disk_size` | `5G` | default virtual disk size |
| `default_memory_size` | `1G` | default vRAM size |
| `default_cpu_count` | `1` | default vCPU count |
| `disk_min_gib` / `disk_max_gib` | `4` / `40` | accepted disk range in GiB |
| `memory_min_gib` / `memory_max_gib` | `1` / `4` | accepted memory range in GiB |
| `cpu_min_count` / `cpu_max_count` | `1` / `4` | accepted vCPU range |
| `ssh_key_type` | `ed25519` | key type generated per VM |
| `ssh_key_name` | `id_ed25519` | filename of the generated key pair |
| `default_template` | `cloud-init.yaml` | default template when several exist |

When tweaking resource limits, it is generally better to raise values than to lower them. The minimums (`disk_min_gib` and `memory_min_gib`) match the [Ubuntu Server cloud-image system requirements](https://ubuntu.com/server/docs/reference/installation/system-requirements/) and should stay unchanged. Multipass allows lower values (its CLI minimums are `1G` disk and `512M` memory), but those are too low to boot any of the Ubuntu images offered by the Multipass. The CPU minimum (`cpu_min_count`) stays at `1`, since fewer than one CPU is not a valid allocation.

## Tests

Bats and its helper libraries are git submodules vendored under `test/`, so a fresh clone needs them initialized first:

```bash
git submodule update --init --recursive
```

Then run the suite from the root of the project:

```bash
test/bats/bin/bats -p test
```

You can run tests without Multipass installed. Use the `--filter-tags` flag to run a part of the suite, e.g., `test/bats/bin/bats -p test --filter-tags ask_size` to run tests only for the `ask_size` function.

The scripts in `helpers/` are manual dev utilities, not a part of the test suite.

## Known issues

### IPv4 resolution of `.local` names fails on Linux hosts

Reproduced on Ubuntu: with `mdns4_minimal` in `nsswitch.conf`, `.local` names of Multipass VMs fail to resolve over IPv4. `ping`, `ssh`, and `getent` fail (exit 2), and `avahi-resolve -4` times out. With `mdns_minimal`, the names resolve, but only over IPv6.

**Reason:** Multipass's own NAT rules intercept bridged IPv4 mDNS traffic. Multipass loads `br_netfilter`, so bridged frames pass through iptables (`bridge-nf-call-iptables=1`). Its `MASQUERADE` rule for the VM subnet matches mDNS replies sent to `224.0.0.251` (an address outside the subnet), rewriting them to the bridge's address with a random source port. Avahi rejects it as an "invalid source port". IPv6 is unaffected because Multipass sets up no IPv6 NAT rules. macOS hosts are unaffected because Multipass on macOS does not use this iptables/`br_netfilter` NAT path.

**Workaround:** The least intrusive option is to switch from `mdns4_minimal` (IPv4 only) to `mdns_minimal` (IPv4 and IPv6).

```bash
sudo sed -i 's/mdns4_minimal/mdns_minimal/' /etc/nsswitch.conf
```
