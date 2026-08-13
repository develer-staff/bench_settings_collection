# Settings collection for Test Bench PC

## Plug-in USB devices

Copy all udev rules into:

`/etc/udev/rules.d`

Like:

`$ sudo cp udev/* /etc/udev/rules.d/`

You should be root.

Reload confings with udavadm command:

`$ sudo udevadm control --reload-rules && udevadm trigger`

Before to do this check if all usb devices are unpluged.

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

Edit `ansible/inventory/hosts.yml` for the bench nodes (`ansible_user: develer`).
On first bootstrap, if `develer` does not exist yet, connect as `root` (or `collaudo`) once.

SSH uses username/password (`ansible_user` + `ansible_ssh_pass`).

Create per-host secrets:

```bash
cd ansible
cp inventory/host_vars/solaris.yml.example inventory/host_vars/solaris.yml
# edit ansible_ssh_pass, ansible_become_pass, develer_password, collaudo_password
ansible-vault encrypt inventory/host_vars/solaris.yml
```

Repeat for each host (`pathfinder`, …). If login and sudo share the same password for `develer`, set `ansible_ssh_pass` and `ansible_become_pass` to the same value.

The playbook creates `develer` with sudo (`wheel`) first, then adds `collaudo` without sudo.

Ensure `bin/dboard` is present in the repo, then:

```bash
ansible-playbook playbooks/new_installation.yml --ask-vault-pass
```

After Docker group membership changes, users must log out and back in (or reboot) for the new groups to apply.

### Bash script

```bash
./new_installation.sh
```
