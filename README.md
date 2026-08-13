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

Optional git checkout as `collaudo` (set in host_vars):

```yaml
bench_git_repo_url: "git@nome_repo:org/repo.git"
bench_git_ssh_host: "nome_repo"
bench_git_ssh_hostname: "github.com"
bench_git_dest: "/home/collaudo/src/repo"
```

The playbook generates an SSH key on the control machine, prints the public key, waits for you to register it, installs `~/.ssh/id_<type>_<host>` for `collaudo`, writes a matching `~/.ssh/config` Host entry, then clones the repo.

Then:

```bash
ansible-playbook playbooks/new_installation.yml --ask-vault-pass
```

After Docker group membership changes, users must log out and back in (or reboot) for the new groups to apply.

### Bash script

```bash
./scripts/new_installation.sh
```
