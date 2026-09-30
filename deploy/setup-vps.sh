#!/usr/bin/env bash
# Bootstrap a fresh Ubuntu 24.04 VPS for the Postgres stack.
# Usage (as root):  bash setup-vps.sh [username]
# Requires: root already has your SSH key in /root/.ssh/authorized_keys
set -euo pipefail

USER_NAME="${1:-deploy}"

# Without a key the hardening step below (PasswordAuthentication no) locks you out.
if [ ! -s /root/.ssh/authorized_keys ]; then
  echo "❌ /root/.ssh/authorized_keys is empty. Run from your laptop first:  ssh-copy-id root@<VPS_IP>"
  exit 1
fi

echo "==> Packages"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
DEBIAN_FRONTEND=noninteractive apt-get install -y git curl ufw fail2ban unattended-upgrades

echo "==> User: $USER_NAME"
if ! id "$USER_NAME" &>/dev/null; then
  adduser --disabled-password --gecos "" "$USER_NAME"
  install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "/home/$USER_NAME/.ssh"
  install -m 600 -o "$USER_NAME" -g "$USER_NAME" /root/.ssh/authorized_keys "/home/$USER_NAME/.ssh/authorized_keys"
fi

echo "==> Docker"
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
usermod -aG docker "$USER_NAME"

echo "==> Firewall (SSH only — Postgres stays on 127.0.0.1)"
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw --force enable

echo "==> Swap 2G"
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "==> Directories"
install -d -o "$USER_NAME" -g "$USER_NAME" /opt/pg /opt/pg-backups

echo "==> SSH hardening"
# 00- prefix → loaded first → wins over cloud-init's 50-cloud-init.conf
cat > /etc/ssh/sshd_config.d/00-hardening.conf <<'EOF'
PasswordAuthentication no
PermitRootLogin no
EOF
sshd -t && systemctl restart ssh

echo
echo "✅ Done. Test in a NEW terminal before closing this one:"
echo "   ssh $USER_NAME@$(hostname -I | awk '{print $1}')"
