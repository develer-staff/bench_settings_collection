#!/bin/bash

trap ctrl_c INT

function ctrl_c() {
  echo "Bye!"
  exit 1
}

sudo whoami

echo -n "Install basic packages.."
sudo dnf install openssh-server openssl \
  git git-lfs direnv tmux \
  python3.10 python3.10-devel.x86_64 \
  gcc \
  -y
sudo systemctl enable --now sshd
echo "..done"

echo -n "Copy .develer_profile and .logo"
cp ./conf/develer_profile ~/.develer_profile
cp ./conf/logo ~/.logo
echo "..done"

echo -n "Add local settings to .bashrc"
cat <<'EOF' >>~/.bash_profile
if [ -f .develer_profile ]; then
    . ~/.develer_profile
fi
EOF
echo "..done"

echo -n "Install docker"
sudo dnf remove podman buildah -y
sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

sudo systemctl enable --now docker

sudo usermod -aG docker develer
sudo usermod -aG docker collaudo
echo "..done"

echo -n "Install Insync"
sudo rpm --import https://d2t3ff60b2tol4.cloudfront.net/repomd.xml.key

sudo cat <<'EOF' >/tmp/insync.repo
[insync]
name=insync repo
baseurl=http://yum.insync.io/fedora/44/
gpgcheck=1
enabled=1
EOF
sudo cp /tmp/insync.repo /etc/yum.repos.d/insync.repo
sudo dnf install insync -y
echo "..done"

echo "Extra.."
mkdir ~/.local/bin
cp bin/dboard ~/.local/bin/
echo "..done"

echo -n "Add develer sudoes user"
sudo useradd -m -G wheel develer
sudo passwd develer
echo "..done"

echo -n "Remove collaudo from sudoers group"
sudo gpasswd -d collaudo wheel
echo "..done"
