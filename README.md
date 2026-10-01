# multipass-cloud-init

A wrapper around Multipass that launches and destroys VMs from [cloud-init](https://cloudinit.readthedocs.io/) templates, with per-VM SSH keys and ssh config entries generated automatically. Each VM gets an alias you can use with `ssh`, `scp`, and `rsync` without per-host configuration, and it works with VS Code [Remote Development using SSH](https://code.visualstudio.com/docs/remote/ssh) out of the box.

### Why a wrapper?

The goal is to simplify SSH access. Instead of remembering the full `multipass launch` invocation (image, disk, memory, CPUs, cloud-init file), the script prompts for each value, validates it, waits for the VM to come up, and enters an SSH session on the new VM.

Built-in Multipass commands keep working unchanged: `multipass shell`, `multipass exec`, and `multipass transfer` (the `scp` equivalent). One limitation of this wrapper: `multipass delete --purge` alone leaves behind the local files under `vms/` and the host entry in `~/.ssh/known_hosts`. `mp-delete.sh` handles the full cleanup: it purges the VM from Multipass, removes its host entries via `ssh-keygen -R`, and deletes its local directory under `vms/`.

### Why generate a per-VM SSH key pair, and why plain `ssh` at all?

Multipass injects its own key into every VM, but it is stored at a root-owned path (on macOS: `/var/root/Library/Application Support/multipassd/ssh-keys/id_rsa`), so anything outside Multipass's own commands needs `sudo ssh -i` with a quoted path or writing an ssh config by hand. Generating a fresh key into the project directory at launch time avoids all of that.

### Requirements

**Note:** The scripts are not POSIX compliant.

1. [Install Multipass](https://canonical.com/multipass/install)

2. The scripts use a few CLI tools in addition to Multipass. Most of these ship with most distros. If any are missing, the script stops and tells you which ones to install:

    * `ssh`
    * `ssh-keygen`
    * `ssh-keyscan`
    * `sed`
    * `jq`
    * `bc`

3. Each VM gets its own ssh `config` file, but the ssh client does not read it automatically, so you would have to pass `-F <file>` on every command. Instead, propagate the per-VM configs with an [Include directive](https://man.openbsd.org/ssh_config#Include) in your main `~/.ssh/config`:

```bash
nano ~/.ssh/config
```

```text
Include <absolute-path>/multipass-cloud-init/vms/*/config
```

4. A cloud-init template. The launch script needs at least one template in `templates/` to work. The repo comes with `templates/cloud-init.yaml`, which is the baseline for any future cloud-inits. See [Custom cloud-init templates](#custom-cloud-init-templates).

### Installation with symlinks (recommended)

Why symlinks? With this approach you can invoke the launch and delete scripts from anywhere in the terminal session as you would with any other command. Any artifacts generated during execution are stored in the project directory.

1. Make directories for storing the whole project and for storing symlinks to the scripts:

```bash
mkdir -p ~/.local/scripts ~/.local/bin
```

2. Add `~/.local/bin` to your `PATH`. You can do this in any shell config file, but `.profile` (bash) or `.zprofile` (zsh) is recommended. Some distros already include this path in their config files, so you may just need to `source` the config file.

3. Clone this repo to the `~/.local/scripts` dir:

```bash
git clone https://github.com/leambeam/multipass-cloud-init.git ~/.local/scripts/multipass-cloud-init
```

4. Create symlinks:

```bash
ln -s ~/.local/scripts/multipass-cloud-init/mp-launch.sh ~/.local/bin/mp-launch
ln -s ~/.local/scripts/multipass-cloud-init/mp-delete.sh ~/.local/bin/mp-delete
```

Alternatively, you can just clone the repo and run `mp-launch.sh` and `mp-delete.sh` from the root directory. You can also run them from other places (e.g., via relative or absolute paths). All paths and artifacts remain anchored to the project directory.

```bash
./mp-launch.sh
bash mp-delete.sh
```

### Directory structure

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

### Custom cloud-init templates

The launch script auto-discovers every `.yaml` and `.yml` file in `templates/`. The easiest way to make a custom template is to copy the existing one and add your configs on top of it:

```bash
cp templates/cloud-init.yaml templates/my-template.yaml
```

Everything in the copied file is required. Do not remove or change any of it (apart from the commented out parts). Add your own configs on top of it instead:

* the `ssh_authorized_keys: []` line. The script replaces its contents with the generated public key. Without this line, key injection fails and you will not be able to log in.
* the `ubuntu` user. The generated ssh config entry hardcodes `User ubuntu` (and the script connects as `ubuntu@<name>`), so changing or removing the user breaks the login.
* the `avahi-daemon` package and its `systemctl enable` line. The script connects to `<name>.local` and writes that name into the ssh config, so mDNS must be running on the VM. Without it, the connection fails.

See the [cloud-init docs](https://cloudinit.readthedocs.io/) for the full range of directives you can add.

### Usage

Launch a VM by passing its name as the only argument:

```bash
mp-launch <name>
```

The name must start with a letter, end with a letter or digit, and contain only letters, digits, and hyphens in between (e.g., `vm-111`). If the name or its directory under `vms/` is already taken, a random suffix is appended instead of failing.

`mp-launch.sh` then asks, in order:

1. **Ubuntu image**: numbered list (22.04 LTS, 24.04 LTS, 25.10, 26.04 LTS), default `26.04`. The prompt repeats if the image isn't found on Multipass.
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

### Settings

`readonly` defaults and limits live at the top of `mp-launch.sh`. Edit them there. The prompts show the new defaults and enforce the new limits.

| Variable | Default | Meaning |
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

When tweaking resource limits, it is generally better to raise values than to lower them. The minimum values (`disk_min_gib` and `memory_min_gib`) match the [Ubuntu server system requirements](https://ubuntu.com/server/docs/reference/installation/system-requirements/) and should stay unchanged: Multipass allows lower values ([its defaults are 512M disk and 128M RAM](https://canonical.com/multipass/docs/latest/reference/command-line-interface/launch/)), but some of the images won't boot with them.

### How to run tests

Bats and its helper libraries are git submodules vendored under `test/`, so a fresh clone needs them initialized first:

```bash
git submodule update --init --recursive
```

Then run the suite from the root of the project:

```bash
test/bats/bin/bats -p test/
```

You can run tests without Multipass installed. Use the `--filter-tags` flag to run a part of the suite, e.g. `test/bats/bin/bats test/ --filter-tags ask_size` to run tests only for the `ask_size` function.
