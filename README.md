# Settings collection for Test Bench PC

## Plug-in USB devices

Udev rules live in `conf/udev/` and are installed by the Ansible playbook (`install_udev` task) into `/etc/udev/rules.d`, then reloaded.

Manual equivalent:

```bash
sudo cp conf/udev/* /etc/udev/rules.d/
sudo udevadm control --reload && sudo udevadm trigger
```

Before doing this, unplug USB devices.

## New PC installation

The first installation can be done with Ansible (recommended) or the bash script.
Both automate the major part of bench configuration and support only Fedora for now.

### Ansible

#### Prerequisites (control machine)

Install these on the machine where you run `ansible-playbook` (not on the bench nodes):

```bash
sudo dnf install ansible sshpass
pip install passlib
# or: sudo dnf install python3-passlib
```

`passlib` is required for the `password_hash` filter used when creating `develer` / `collaudo`.
`sshpass` is required for SSH password authentication.

#### Inventory and secrets

Edit `inventory/hosts.yml` for the bench nodes (`ansible_user: develer`).
On first bootstrap, if `develer` does not exist yet, connect as `root` (or `collaudo`) once.

SSH uses username/password (`ansible_user` + `ansible_ssh_pass`).

Create per-host secrets:

```bash
cp inventory/host_vars/solaris.yml.example inventory/host_vars/solaris.yml
# edit ansible_ssh_pass, ansible_become_pass, develer_password, collaudo_password
ansible-vault encrypt inventory/host_vars/solaris.yml
```

Repeat for each host (`pathfinder`, …). If login and sudo share the same password for `develer`, set `ansible_ssh_pass` and `ansible_become_pass` to the same value.

The playbook creates `develer` with sudo (`wheel`) first, then adds `collaudo` without sudo.

Source files used by the playbook:

- `conf/develer_profile`, `conf/logo` → user homes
- `utils/dboard` → `/usr/local/bin/dboard` (root, mode 0755)
- `conf/udev/*.rules` → `/etc/udev/rules.d/`
- `images/Devel-background-2.png` → desktop + GDM login wallpaper

Optional git checkouts as `collaudo` — define **per host** in `inventory/host_vars/<hostname>.yml`
(not in the role defaults). Each entry runs `checkout_repo.yml`:

```yaml
# inventory/host_vars/solaris.yml
bench_git_repos:
  - repo_url: "git@electronic_keystop_collaudo:develersrl/electronic_keystop_collaudo.git"
    ssh_host: "electronic_keystop_collaudo"
    ssh_hostname: "github.com"
    dest: "/home/collaudo/src/electronic_keystop_collaudo"
    version: main

# inventory/host_vars/pathfinder.yml can have a different list
```

For each entry the playbook generates an SSH key, prints the public key, waits for registration, installs `~/.ssh/id_<type>_<ssh_host>` for `collaudo`, writes a matching `~/.ssh/config` Host block, then clones the repo.

Then:

```bash
ansible-playbook playbooks/new_installation.yml --ask-vault-pass
```

Run a single section with `--tags` (also pass `--limit` if needed):

```bash
ansible-playbook playbooks/new_installation.yml --ask-vault-pass --tags checkout_repo
ansible-playbook playbooks/new_installation.yml --ask-vault-pass --tags udev --limit solaris
```

Available tags: `hostname`, `packages`, `users`, `local_profile`, `wallpaper`, `utils`, `docker`, `insync`, `udev`, `checkout_repo`.

After Docker group membership changes, users must log out and back in (or reboot) for the new groups to apply.

### Bash script

```bash
./scripts/new_installation.sh
```
