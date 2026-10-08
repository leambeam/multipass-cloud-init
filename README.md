# multipass-cloud-init

A wrapper around Multipass that launches and destroys VMs from [cloud-init](https://cloudinit.readthedocs.io/) templates, with per-VM SSH keys and ssh config entries generated automatically. Each VM gets an alias you can use with `ssh`, `scp`, and `rsync` without per-host configuration, and it works with VS Code [Remote Development using SSH](https://code.visualstudio.com/docs/remote/ssh) out of the box.

## Why a wrapper?

The goal is to simplify remote access. Instead of remembering the full `multipass launch` invocation (image, disk, memory, CPUs, cloud-init file), the script prompts for each value, validates it, waits for the VM to come up, and enters an SSH session on the new VM.

Built-in Multipass commands keep working unchanged: `multipass shell`, `multipass exec`, and `multipass transfer` (the `scp` equivalent). One limitation of this wrapper: `multipass delete --purge` alone leaves behind the local files under `vms/` and the host entry in `~/.ssh/known_hosts`. `mp-delete.sh` handles the full cleanup: it purges the VM from Multipass, removes its host entries via `ssh-keygen -R`, and deletes its local directory under `vms/`.

## Why generate a per-VM SSH key pair, and why plain `ssh` at all?

Multipass injects its own key into every VM, but it is stored at a root-owned path (on macOS: `/var/root/Library/Application Support/multipassd/ssh-keys/id_rsa`), so anything outside Multipass's own commands needs `sudo ssh -i` with a quoted path or writing an ssh config by hand. Generating a fresh key into the project directory at launch time avoids all of that.

## Requirements

**Note:** The scripts are not POSIX compliant.
1. [Install Multipass](https://canonical.com/multipass/install)

2. The scripts use a few CLI tools in addition to Multipass. Most of these ship by default on common distros. If any are missing, the script stops and tells you which ones to install:

    * `ssh`
    * `ssh-keygen`
    * `ssh-keyscan`
    * `sed`
    * `jq`
    * `bc`

## Installation with symlinks (recommended)

Why symlinks? With this approach you can invoke the launch and delete scripts from anywhere in the terminal session as you would with any other command. Any artifacts generated during execution are stored in the project directory.

1. Make directories for storing the whole project and for storing symlinks to the scripts:

   **Note:** [Snap doesn't have access to hidden directories](https://documentation.ubuntu.com/security/security-features/privilege-restriction/snap-confinement/#interface-connections). Thus, you should use a non-hidden directory on Linux (e.g., `~/scripts`), while on Mac you can use a hidden one (e.g., `~/.scripts`).

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

5. Configure ssh to read the per-VM configs with an [Include directive](https://man.openbsd.org/ssh_config#Include) in your main `~/.ssh/config` (otherwise you would have to pass `-F <file>` on every command):

   ```bash
   nano ~/.ssh/config
   ```

   ```text
   Include <absolute-path>/multipass-cloud-init/vms/*/config
   ```

Alternatively, you can just clone the repo and run `mp-launch.sh` and `mp-delete.sh` from the root directory. You can also run them from other places (e.g., via relative or absolute paths). All paths and artifacts remain anchored to the project directory.

```bash
./mp-launch.sh
bash mp-delete.sh
```

## Usage

Launch a VM by passing its name as the only argument:

```bash
mp-launch <name>
```

The name must start with a letter, end with a letter or digit, and contain only letters, digits, and hyphens in between (e.g., `vm-111`). If the name or its directory under `vms/` is already taken, a random suffix is appended instead of failing.

`mp-launch.sh` then asks, in order:

1. **Ubuntu image**: numbered list (22.04 LTS, 24.04 LTS, 26.04 LTS, daily:26.10), default `26.04`. The prompt repeats if the image isn't found on Multipass.
2. **Disk space**: integer or decimal with an `M`/`G` suffix (e.g. `1000M`, `5G`, `5.5G`). Range `4G`–`40G`, default `5G`.
3. **Memory**: same format as disk. Range `1G`–`4G`, default `1G`.
4. **CPUs**: whole number `1`–`4`, default `1`.
5. **Template**: only if `templates/` holds more than one `.yaml`/`.yml` file: numbered list, default `cloud-init.yaml` (only when that file exists). If exactly one template exists, it is auto-selected.

Enter accepts the shown default. Invalid answers re-prompt.

Delete one or more VMs by passing their names:

```bash
mp-delete <name-1> <name-2> <name-3>
```

`mp-delete.sh` prompts only when a VM isn't found on Multipass.

## Uninstall

Removing the wrapper is just deleting the symlinks and the repo directory. The VMs themselves live in Multipass and are left untouched, so delete them first if you no longer need them (`mp-delete <name>` also purges the VM and its `~/.ssh/known_hosts` entries):

```bash
mp-delete <name>
```

Then remove the symlinks and the repo:

```bash
rm ~/.local/bin/mp-launch ~/.local/bin/mp-delete
rm -rf ~/scripts/multipass-cloud-init
```

If you added the `Include` line to `~/.ssh/config`, remove that line too so it doesn't point at the deleted path.

## Directory structure

```text
multipass-cloud-init/
├── mp-launch.sh                # wrapper around 'multipass launch'
├── mp-delete.sh                # wrapper around 'multipass delete --purge' and local cleanup
├── templates/                  # cloud-init templates; auto-discovered by the launch script
│   └── cloud-init.yaml
├── vms/                        # created at launch time; one directory per VM
│   └── <name>/
│       ├── cloud-init.yaml     # copy of the template with the public key injected
│       ├── config              # ssh config
│       ├── id_ed25519          # per-VM private key
│       └── id_ed25519.pub      # per-VM public key
└── test/                       # Bats test suite
    ├── common-setup.bash       # shared setup sourced by every test file
    ├── mp-launch.bats          # tests for mp-launch.sh
    ├── mp-delete.bats          # tests for mp-delete.sh
    ├── bats/                   # Bats binary (git submodule)
    └── test_helper/
        ├── fixture-builders.bash   # fake filesystem fixtures for tests
        ├── stub-builders.bash      # stub helpers (mock multipass, etc.)
        ├── bats-assert/            # helper libs (git submodules)
        ├── bats-file/
        ├── bats-mock/
        └── bats-support/
```

## Custom cloud-init templates

The launch script auto-discovers every `.yaml` and `.yml` file in `templates/`. The easiest way to make a custom template is to copy the existing one and add your configs on top of it:

```bash
cp templates/cloud-init.yaml templates/my-template.yaml
```

Everything in the copied file is required. Do not remove or change any of it (apart from the commented out parts). Add your own configs on top of it instead:

* the `ssh_authorized_keys: []` line. The script replaces its contents with the generated public key. Without this line, key injection fails and you will not be able to log in.
* the `ubuntu` user. The generated ssh config entry hardcodes `User ubuntu` (and the script connects as `ubuntu@<name>`), so changing or removing the user breaks the login.
* the `avahi-daemon` package and its `systemctl enable` line. The script connects to `<name>.local` and writes that name into the ssh config, so mDNS must be running on the VM. Without it, the connection fails.

See the [cloud-init docs](https://cloudinit.readthedocs.io/) for the full range of directives you can add.

## Settings

`readonly` defaults and limits live at the top of `mp-launch.sh`. Edit them there. The prompts show the new defaults and enforce the new limits.

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

When tweaking resource limits, it is generally better to raise values than to lower them. The minimum values (`disk_min_gib` and `memory_min_gib`) match the [Ubuntu server system requirements](https://ubuntu.com/server/docs/reference/installation/system-requirements/) and should stay unchanged: Multipass allows lower values ([its defaults are 512M disk and 128M RAM](https://canonical.com/multipass/docs/latest/reference/command-line-interface/launch/)), but some of the images won't boot with them. The CPU minimum (`cpu_min_count`) stays at `1`, since fewer than one CPU is not a valid allocation.

## Tests

Bats and its helper libraries are git submodules vendored under `test/`, so a fresh clone needs them initialized first:

```bash
git submodule update --init --recursive
```

Then run the suite from the root of the project:

```bash
test/bats/bin/bats -p test/
```

You can run tests without Multipass installed. Use the `--filter-tags` flag to run a part of the suite, e.g. `test/bats/bin/bats -p test/ --filter-tags ask_size` to run tests only for the `ask_size` function.

## Known bugs

### `.local` names resolve only over IPv6 (Linux hosts)

Reproduced on Ubuntu, where `.local` names of Multipass VMs resolve only over IPv6. With `mdns4_minimal` in `nsswitch.conf`, `ping`, `ssh`, and `getent` fail (exit 2), and `avahi-resolve -4` times out. With `mdns_minimal` they work, but only over IPv6.

**Reason:** Multipass's own NAT rules intercept bridged IPv4 mDNS traffic. Multipass loads `br_netfilter`, so bridged frames pass through iptables (`bridge-nf-call-iptables=1`). Its `MASQUERADE` rule for the VM subnet matches mDNS replies sent to `224.0.0.251` (an address outside the subnet), rewriting them to the bridge's address with a random source port. Avahi rejects it as an "invalid source port". IPv6 is unaffected because Multipass sets up no IPv6 NAT rules.

This is a Linux-host-only issue: the reason is the iptables/`br_netfilter` NAT path, which macOS Multipass does not use, so macOS hosts are unaffected.

**Workaround:** the most non-intrusive workaround would be to switch from `mdns4_minimal` (IPv4 only) to `mdns_minimal` (IPv4 + IPv6).

```bash
sudo sed -i 's/mdns4_minimal/mdns_minimal/' /etc/nsswitch.conf
```
