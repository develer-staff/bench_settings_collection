# Settings collection for Test Bench PC

Ansible playbook to provision test-bench PCs (Fedora + LXDE): users, desktop, Docker, Tailscale, udev, git checkouts, and more.

Supported target: **Fedora** (with LXDE desktop).

---

## What the playbook does

It runs the `bench_new_installation` role on hosts in the `benches` group. Step order:

| Tag | What it does |
|---|---|
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

## Repository layout

```
playbooks/new_installation.yml   # main playbook
roles/bench_new_installation/    # role tasks
inventory/hosts.yml              # bench host list
inventory/host_vars/<host>.yml   # per-host secrets and config (vault)
conf/                            # profiles, udev rules, logos
images/                          # wallpapers
utils/                           # binaries (e.g. dboard)
scripts/                         # legacy bash scripts
```

---

## Prerequisites (control machine)

On the machine where you run `ansible-playbook`:

```bash
sudo dnf install ansible sshpass
pip install passlib
# or: sudo dnf install python3-passlib
```

- `sshpass` — SSH password authentication  
- `passlib` — password hashing for `develer` / `collaudo`

---

## Inventory and secrets

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

### Per-host secrets

Copy the template and encrypt with Vault:

```bash
cp inventory/host_vars/client_credential.yml.example inventory/host_vars/solaris.yml
# edit passwords / keys
ansible-vault encrypt inventory/host_vars/solaris.yml
```

Typical fields:

| Variable | Purpose |
|---|---|
| `ansible_ssh_pass` | SSH password for `ansible_user` |
| `ansible_become_pass` | sudo password |
| `develer_password` | Password for user `develer` |
| `collaudo_password` | Password for user `collaudo` |
| `bench_git_repos` | List of repos to clone as `collaudo` |
| `bench_keyring_passwords` | Secrets prepared for keyring / local helper files |
| `bench_tailscale_auth_key` | Tailscale auth key (device join only; optional) |

Do not commit plaintext `inventory/host_vars/` files (see `.gitignore`).

---

## How to run

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
`hostname`, `users`, `local_profile`, `wallpaper`, `utils`, `lxde_cleanup`, `packages`, `keyring`, `docker`, `insync`, `tailscale`, `udev`, `checkout_repo`.

---

## Main steps in detail

### Users

1. Create `develer` in group `wheel` (sudo)  
2. Create `collaudo` **without** sudo  
3. If `collaudo` was in `wheel`, remove it  

### LXDE desktop

- Bash profile + logo from `conf/`  
- Wallpaper from `images/` via PCManFM config  
- Package cleanup (`bench_lxde_remove_packages` in role defaults; overridable per host)  

### Docker

Removes `podman`/`buildah`, installs Docker CE, enables the service, adds `develer` and `collaudo` to the `docker` group.  
After group changes, users must **log out and back in** (or reboot).

### Tailscale

1. Adds the official repo and installs `tailscale`  
2. Starts `tailscaled`  
3. If `bench_tailscale_auth_key` is set, runs `tailscale up`  

The auth key enrolls a **device**, not a user. It is only needed for the first join; after reboot the node rejoins on its own.

If **Device approval** is enabled in the admin console, `tailscale up` will wait until you approve the node at  
https://login.tailscale.com/admin/machines  
(the playbook shows a warning before continuing).

Generate auth keys at:  
https://login.tailscale.com/admin/settings/keys

### Udev

Copies rules from `conf/udev/` into `/etc/udev/rules.d/` and reloads/triggers udev.  
Unplug USB devices before running the `udev` tag.

Manual equivalent:

```bash
sudo cp conf/udev/* /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
```

### Git checkout (as `collaudo`)

For each entry in `bench_git_repos` (from host_vars):

1. Generate (or use) an SSH key for the repo  
2. Print the public key and wait until you register it as a GitHub **deploy key** (no write access)  
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

### Keyring / service passwords

The `keyring` tag prepares credentials from `bench_keyring_passwords` (host_vars; prefer vault).  
On LXDE the graphical keyring is not always reachable from Ansible over SSH, so the task also writes helper files under the `collaudo` home for operational use.

---

## Legacy bash script

The original bootstrap script still exists (less complete than the playbook):

```bash
./scripts/new_installation.sh
```

Prefer Ansible for new installations.

---

## Operational notes

- Ansible access: SSH with username/password (`sshpass`), sudo via `become`  
- After Docker group changes: re-login required  
- Tailscale with device approval: approve the node in the admin console  
- Do not commit plaintext host_vars, keys, or passwords  
- Wallpapers / logos live under `images/` and `conf/logos/`
