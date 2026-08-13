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

Edit `ansible/inventory/hosts.yml` for the bench nodes, then create per-host secrets:

```bash
cd ansible
cp inventory/host_vars/solaris.yml.example inventory/host_vars/solaris.yml
# edit ansible_become_pass and develer_password
ansible-vault encrypt inventory/host_vars/solaris.yml
```

Repeat for each host (`pathfinder`, …). Prefer SSH keys; set `ansible_ssh_pass` only if needed.

Ensure `bin/dboard` is present in the repo, then:

```bash
ansible-playbook playbooks/new_installation.yml --ask-vault-pass
```

After Docker group membership changes, users must log out and back in (or reboot) for the new groups to apply.

### Bash script

```bash
./new_installation.sh
```
