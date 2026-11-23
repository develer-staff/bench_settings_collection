# Settings collection for Test Bench PC

Ansible playbook to provision test-bench PCs (Fedora + LXDE): users, desktop, Docker, Tailscale, udev, git checkouts, and more.

Supported target: **Fedora** (with LXDE desktop), see [7.1.5 Host setup guide](https://docs.google.com/document/d/1B2qIqUBqo7_LXgRBi_uQIBeSr00K8Y5IeKFlFXRfMqk/edit?tab=t.0) for starting installation.

---

## Table of Contents

- [1. Fedora Custom Distro](#1.-fedora-custom-distro)
  - [1.1 Abstract](#11-abstract)
  - [1.2 Apply patches](#12-apply-patches)
  - [1.3 Customizations](#13-customizations)
  - [1.4 To build](#14-to-build)
  - [1.5 To flash](#15-to-flash)
- [2. Ansible Playbooks](#2.-ansible-playbooks)
  - [2.1 Repository layout](#21-repository-layout)
  - [2.2 Inventory and secrets](#22-inventory-and-secrets)
  - [2.3 Prerequisites](#23-prerequisites)
  - [2.4 `rclone_setup` playbook](#24-rclonesetup-playbook)
  - [2.5 `build_iso` playbook](#25-buildiso-playbook)
  - [2.6 `flash_iso` playbook](#26-flashiso-playbook)
  - [2.7 `new_installation` playbook](#27-newinstallation-playbook)
  - [2.8 `upgrade` playbook](#28-upgrade-playbook)

# 1. Fedora Custom Distro

## 1.1 Abstract

A custom distribution of Fedora LXDE Spin is built for the `collaudo` PCs.

It is based on Fedora Project's [official repository](https://forge.fedoraproject.org/releng/kiwi-descriptions) which is included as a repository's git submodule.
It configures [Kiwi-Ng](https://osinside.github.io/kiwi/) image descriptions to build a custom Fedora 44 expandable disk image.

## 1.2 Apply Patches

The patch can be found in `conf/0001-Fedora-44-LXDE-Spin-kiwi-description.patch`.
To apply them (inside `kiwi-descriptions` folder):

```bash
$ git apply ../conf/0001-Fedora-44-LXDE-Spin-kiwi-description.patch
```

> Please note that the patch should match the Fedora version branch to be applied successfully (ex. Fedora 44 patch must be applied on `f44` branch)

## 1.3 Customizations

- `Fedora.kiwi`: added `openssh-server` and `openssl` packages necessary to run Ansible
- `boot.xml`: changed `oem` image type to create ISO, reboot after installation and expand root partition automatically
- `lxde.xml`: removed unnecessary packages
- `users.xml`: created `collaudo` group and user
- `config.sh`: enabled `sshd` service and prevented root user from being deleted

## 1.4 To build

1. Local setup bootstrap, if not already done (should be done only once)
```bash
$ ./script/bootstrap.sh
```

2. Build the OEM self-installing ISO
```bash
$ ./script/build.sh
```

3. The build process should take a few minutes (15 minutes on a ThinkPad Laptop).
The output image is saved in `./output-build`.

Alternatively, the steps are automated by the Ansible playbook `playbooks/build_iso.yml`.

### Tested environment

The scripts where tested on Ubuntu 26.04 building Fedora 44.
In Fedora, if SELinux is enabled (`setenforce 1`), building inside the container will cause rsync errors related to extended attributes.

## 1.5 To flash
Flash the `*.install.iso` file onto the USB device outside the container
```bash
$ ./script/flash.sh [device] # (ex. /dev/sde)
```

The ansible playbook `./playbooks/flash_iso.yml` is also provided to perform the same steps.

# 2. Ansible Playbooks

## 2.1 Repository layout

```
playbooks/rclone_setup.yml       # rclone_setup playbook
playbooks/build_iso.yml          # build_iso playbook
playbooks/flash_iso.yml          # flash_iso playbook
playbooks/new_installation.yml   # new_installation playbook
playbooks/upgrade.yml            # upgrade playbook
roles/bench_new_installation/    # role tasks
inventory/hosts.yml              # bench host list
inventory/host_vars/<host>.yml   # per-host secrets and config (vault)
conf/                            # profiles, udev rules, logos, patches
images/                          # wallpapers
utils/                           # binaries (e.g. dboard)
script/                          # bash scripts
```

---

## 2.2 Prerequisites

### Control machine Requisites

On the machine where you run `ansible-playbook`:

```
sudo dnf install ansible sshpass
pip install passlib
# or: sudo dnf install python3-passlib
```
  
- `sshpass` - SSH password authentication
- `passlib` - password hashing for `develer` / `collaudo`

> [!NOTE]
> `Ubuntu 26.04` changed its default `sudo` implementation from `sudo.ws` to `sudo-rs`.
> Since the new implementation has a different prompt it might cause Ansible to crash when run with `-K` option.
> `become_exe: sudo.ws` was added to fix this problem.

### Managed machine Requisites

The managed machine must have ssh enable and must be reachable by the control machine.

Follow the [7.1.5 Host setup guide](https://docs.google.com/document/d/1B2qIqUBqo7_LXgRBi_uQIBeSr00K8Y5IeKFlFXRfMqk/edit?tab=t.0) to make a fresh Fedora LXDE install.

Create a base user `develer`, psw: `develer`

Install openSSH and enable it:

```
sudo dnf install openssh-server openssl -y
sudo systemctl enable --now sshd
```

Add the Control machine public key to enable ssh connection, by adding it to authorized keys or launching `ssh-copy-id collaudo@host` from the Control machine

After this test that the connection via SSH from control machine to target host is automatic with no prompt to insert any password.

## 2.3 Inventory and secrets

### Hosts

Edit `inventory/hosts.yml`:

```yaml
benches:
  hosts:
    solaris:
      ansible_host: solaris.private
      ansible_user: develer
    pathfinder:
      ansible_host: pathfinder.private
      ansible_user: develer
```

On **first** bootstrap, if `develer` does not exist yet, temporarily use `ansible_user: root` (or `collaudo`).

`rclone_setup`,`build_iso` and `flash_iso` playbooks are meant to be executed on the local machine, therefore the target host is `localhost`.

### Per-host secrets

Copy the template and encrypt with Vault:

```bash
cp inventory/host_vars/client_credential.yml.example inventory/host_vars/solaris.yml
# edit passwords / keys
ansible-vault encrypt inventory/host_vars/solaris.yml
```

**Note**: Always use **_Bench setting Collection Vault Ansible_** from 1password as Vault password 

Typical fields:

| Variable | Purpose |
| --- | --- |
| `ansible_ssh_pass` | SSH password for `ansible_user` |
| `ansible_become_pass` | sudo password |
| `develer_password` | Password for user `develer` |
| `collaudo_password` | Password for user `collaudo` |
| `bench_git_repos` | List of repos to clone as `collaudo` |
| `bench_keyring_passwords` | Secrets prepared for keyring / local helper files |
| `bench_tailscale_auth_key` | Tailscale auth key (device join only; optional) |
| `ansible_deploy_key_private` | Private Deploy key to make first repo checkout  |
| `ansible_deploy_key_public` | Private Deploy key to make first repo checkout |

Do not commit plaintext `inventory/host_vars/` files (see `.gitignore`).

---

### Deploy key for repo checkout

For the first checkout from a git repo ansible need a deploy key with write access.
After the first checkout, the task will generate a read only deploy key and the other key must be deleted.

For `checkout_repo` task to work correctly you must:
- Generate an ssh key with no password using
```
ssh-keygen -t ed25519 -N ""
```
- Copy the public and private key generated in `ansible_deploy_key_private` / `ansible_deploy_key_private` variables of the host inventory yaml
```
    ansible_deploy_key_private: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      ......................
      -----END OPENSSH PRIVATE KEY-----
    ansible_deploy_key_public: "ssh-ed25519 .... ansible@NO-MACHINE"
```

- Add the deploy key to the target Git repo with write access enabled

- Optional: test the key
```
ssh -i /path/to/your/private_deploy_key git@github.com git-receive-pack 'organization/repo-name.git'
```

- After deploy is complete delete the write enable key from the git repos

### Test connection to target host

If all the prerequites are follow, you can ping the target machine using
```
ansible --ask-vault-pass perseverance -m ping
```

And insert the vault password used to encrypt the inventory host file

---

## 2.4 `rclone_setup` playbook

### What the playbook does

It configures `rclone` on your local machine, including keys.

### How to run

From the repo root:

```bash
ansible-playbook playbooks/rclone_setup.yml -K --ask-vault-pass
```

### Secrets

The playbook relies on the encrypted vault `inventory/rclone.yml`.
It contains the following secrets required to setup and interact with Google Drive through `rclone`.


| Variable | Purpose |
| --- | --- |
| `rclone_conf_remote` | remote name (as defined in .conf) |
| `rclone_conf_dir` | where to store rclone files |
| `rclone_conf_path` | `collaudo-iso.conf` configuration file path |
| `rclone_conf_content` | `collaudo-iso.conf` content |
| `rclone_conf_service_path` | `collaudo-iso-service.json` service account file |
| `rclone_conf_service_content` | `collaudo-iso-service.json` content |


### Main steps in detail

1. Downloads `rclone` package if not already done

2. Configures `/etc/rclone/collaudo-iso.conf` configuration with vault secret

3. Configures `/etc/rclone/collaudo-iso-service.json` service account configuration with vault secret

4. Tests whether `rclone` is working

## 2.5 `build_iso` playbook

### Prerequisites

- `rclone` must be configured in your local machine.

### What the playbook does

Automates the end-to-end creation and publication of a custom Fedora ISO image locally.

### How to run

```bash
ansible-playbook playbooks/build_iso.yml -K --ask-vault-pass
```

### Main steps in detail

1. Sync `kiwi-descriptions` repository: pulls and checks out the branch matching the target Fedora version (e.g., f44), recursively initializes submodules, and forces a clean state (force: true) to prevent conflicts with previous patches.

2. Apply customization patch: applies `conf/0001-Fedora-44-LXDE-Spin-kiwi-description.patch`.

3. Build the ISO image: runs `script/build.sh` with elevated privileges from the project root. Skips it if ISO already exists.

4. Move `remote:releases/latest/*.iso` to `remote:releases/old`

5. Publish new ISO: uploads the newly generated ISO to `remote:releases/latest/`, prefixing the filename with the current build date (YYYY-MM-DD_Fedora.x86_64-<version>.install.iso).

> [!WARNING]
> To ensure that the uploaded file has the latest changes, delete the old ISO before running the playbook.

## 2.6 `flash_iso` playbook

### What the playbook does

This playbook downloads and flashes an USB Drive with a custom Fedora ISO.
Automates downloading a Fedora installation ISO from a remote storage provider using rclone and writing it to a target USB device.

### Prerequisites

- `rclone` must be configured in your local machine.

### How to run

From the repo root:

```bash
ansible-playbook playbooks/flash_iso.yml -K --ask-vault-pass
```

### Main steps in detail

1. ISO download: if a custom built ISO is not found in `output_build` it is downloaded from a shared drive through `rclone`.
The latest ISO (found in `collaudo-iso:releases/latest`) name is then retrieved for the following tasks.

2. The image is flashed onto the provided device with the script `./script/flash.sh` (see [above](#15-to-flash)).

3. The USB drive in unmounted and ready to be used.

## 2.7 `new_installation` playbook

### What the playbook does

It runs the `bench_new_installation` role on hosts in the `benches` group. Step order:

| Tag | What it does |
| --- | --- |
| `hostname` | Sets the system hostname to the inventory host name (e.g. `solaris`) |
| `users` | Creates `develer` with sudo (`wheel`), creates `collaudo` without sudo |
| `local_profile` | Copies shell profile and logo into `develer` and `collaudo` homes |
| `wallpaper` | Sets the LXDE (PCManFM) wallpaper from files under `images/` |
| `utils` | Installs `utils/dboard` into `/usr/local/bin` |
| `lxde_cleanup` | Removes unused packages (office, mail, games, media, ABRT, …) |
| `packages` | Installs base packages (git, tmux, python, keyring tools, …) |
| `keyring` | Prepares passwords/secrets for external services (see below) |
| `docker` | Removes podman/buildah, installs Docker CE, adds users to the `docker` group |
| `insync` | Adds the Insync repo and installs the client |
| `tailscale` | Installs Tailscale, starts `tailscaled`, optionally runs `tailscale up` with an auth key |
| `udev` | Copies `conf/udev/*.rules` to `/etc/udev/rules.d` and reloads udev |
| `checkout_repo` | For each repo in `bench_git_repos`: SSH keys, clone as `collaudo`, set `origin` remote |

You can run the full playbook or a single section with `--tags`.

---

### How to run

From the repo root:

```bash
ansible-playbook playbooks/new_installation.yml --ask-vault-pass
```

Single host:

```bash
ansible-playbook playbooks/new_installation.yml --ask-vault-pass --limit solaris
```

Single section:

```bash
ansible-playbook playbooks/new_installation.yml --ask-vault-pass --tags docker --limit solaris
ansible-playbook playbooks/new_installation.yml --ask-vault-pass --tags checkout_repo --limit solaris
ansible-playbook playbooks/new_installation.yml --ask-vault-pass --tags tailscale --limit solaris
```

Available tags:  
`hostname`, `users`, `local_profile`, `wallpaper`, `utils`, `lxde_cleanup`, `lxde_allow_exec`, `packages`, `keyring`, `docker`, `insync`, `tailscale`, `udev`, `checkout_repo`.

---

### Main steps in detail

#### Users

1. Create `develer` in group `wheel` (sudo)  
2. Create `collaudo` **without** sudo  
3. If `collaudo` was in `wheel`, remove it  

#### LXDE desktop

- Bash profile + logo from `conf/`  
- Wallpaper from `images/` via PCManFM config  
- Package cleanup (`bench_lxde_remove_packages` in role defaults; overridable per host)  

#### Docker

Removes `podman`/`buildah`, installs Docker CE, enables the service, adds `develer` and `collaudo` to the `docker` group.  
After group changes, users must **log out and back in** (or reboot).

#### Tailscale

1. Adds the official repo and installs `tailscale`  
2. Starts `tailscaled`  
3. If `bench_tailscale_auth_key` is set, runs `tailscale up`  

The auth key enrolls a **device**, not a user. It is only needed for the first join; after reboot the node rejoins on its own.

If **Device approval** is enabled in the admin console, `tailscale up` will wait until you approve the node at  
https://login.tailscale.com/admin/machines  
(the playbook shows a warning before continuing).

Generate auth keys at:  
https://login.tailscale.com/admin/settings/keys

#### Udev

Copies rules from `conf/udev/` into `/etc/udev/rules.d/` and reloads/triggers udev.  
Unplug USB devices before running the `udev` tag.

Manual equivalent:

```bash
sudo cp conf/udev/* /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
```

#### Git checkout (as `collaudo`)

> [!WARNING]
> GitHub CLI `gh` must be installed and user with admin privileges (deploy keys) must be logged in (`gh auth login`)

For each entry in `bench_git_repos` (from host_vars):

1. Generate (or use) an SSH key for the repo  
2. Uploads temporary public passphrase-less deploy key as a GitHub **deploy key** (no write access)  
3. Checkouts the repository
4. Deletes the temporary deploy key and uploads generated ssh key (with passphrase)
3. Install the key and a `~collaudo/.ssh/config` Host entry  
4. Clone/update the repo as user `collaudo`  
5. Set the `origin` remote (SSH Host alias, or `repo_origin_url` if set)  

Example host_vars entry:

```yaml
bench_git_repos:
  - repo_url_for_checkout: "git@github.com:org/repo.git"
    repo_name: "repo"
    repo_organization: "org"
    repo_hostname: "github.com"
    repo_username: "git"
    repo_dest: "/home/collaudo/src/"
    repo_checkout_branch: main
    ansible_deploy_key_private: |
      -----BEGIN OPENSSH PRIVATE KEY-----
      ...
      -----END OPENSSH PRIVATE KEY-----
    ansible_deploy_key_public: "ssh-ed25519 AAAA... comment"
```

Each host can define a different list, so benches can have different repos.

#### Keyring / service passwords

The `keyring` tag prepares credentials from `bench_keyring_passwords` (host_vars; prefer vault).  
On LXDE the graphical keyring is not always reachable from Ansible over SSH, so the task also writes helper files under the `collaudo` home for operational use.

---

### Legacy bash scripts

The original bootstrap script still exists (less complete than the playbook):

```bash
./script/legacy/new_installation.sh
```

Prefer Ansible for new installations.

---

### Operational notes

- Ansible access: SSH with username/password (`sshpass`), sudo via `become`  
- After Docker group changes: re-login required  
- Tailscale with device approval: approve the node in the admin console  
- Do not commit plaintext host_vars, keys, or passwords  
- Wallpapers / logos live under `images/` and `conf/logos/`

## 2.8 `upgrade` playbook

### What the playbook does

It upgrades a Fedora distro to a new version.

### How to run

From the repo root:

```bash
ansible-playbook playbooks/upgrade.yml --ask-vault-pass
```

### Main steps in detail

1. Checks whether the remote machine is running Fedora, its packages are updated and if is there a pending reboot.

2. Downloads upgrade packages.

3. Triggers offline system reboot.

4. Verifies target version reached.

5. Removes retired packages.

