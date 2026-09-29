# VPS Security Checklist

> أغلب اختراقات Postgres = بورت 5432 مفتوح + باسورد ضعيف.

```mermaid
flowchart LR
    I["Internet"] -->|"22 ✅"| FW["UFW"]
    I -->|"5432 ❌"| FW
    FW --> SSH["sshd (keys only)"]
    SSH -->|"tunnel"| PG["pg @ 127.0.0.1"]
    APP["App (نفس الـ Docker network)"] -->|"pg:5432"| PG
```

## ⚠️ Docker vs UFW

```bash
# ❌ ports: "5432:5432"
ufw status               # 5432 مش مسموح...
nmap -p 5432 VPS_IP      # 5432/tcp open 😱  ← Docker كتب iptables مباشرة

# ✅ ports: "127.0.0.1:5432:5432"
nmap -p 5432 VPS_IP      # 5432/tcp closed
```

## Checklist

| # | Item | Command / Config |
|---|---|---|
| 1 | SSH keys فقط | `PasswordAuthentication no` بـ `/etc/ssh/sshd_config` |
| 2 | No root login | `PermitRootLogin no` |
| 3 | Firewall | `ufw default deny incoming && ufw allow OpenSSH` |
| 4 | Bind localhost | `127.0.0.1:5432:5432` |
| 5 | Strong password | `openssl rand -hex 24` |
| 6 | App user مش superuser | [07-roles](../../07-ops-scaling/docs/01-roles-rls.md) |
| 7 | Auto security updates | `apt install unattended-upgrades` |
| 8 | Brute-force | `apt install fail2ban` |
| 9 | Backups offsite | [03-backups-cron](03-backups-cron.md) |

## App على نفس الـ VPS

```yaml
services:
  api:
    image: my-api
    environment:
      DATABASE_URL: postgres://app:${PG_PASSWORD}@pg:5432/shop   # service name
```
ما في داعي تفتح أي بورت لـ Postgres.

## Pitfall
❌ `POSTGRES_HOST_AUTH_METHOD=trust` → أي حدا بيدخل بدون باسورد
✅ اتركه default (`scram-sha-256`)

Next → [03-backups-cron](03-backups-cron.md)
