# Deploy on a VPS

> VPS نظيف (Ubuntu 24.04) → Docker → repo → `docker compose up -d`.

```mermaid
flowchart TD
    A["ssh root@VPS"] --> B["setup-vps.sh<br/>user + Docker + UFW"] --> C["git clone"]
    C --> D[".env secrets"] --> E["docker compose up -d"] --> F["backup cron"]
```

## Step 1 — Bootstrap (مرة وحدة)

```bash
ssh root@VPS_IP
curl -fsSL https://raw.githubusercontent.com/wesamkhateeb98-creator/postgresql-zero-to-hero/main/10-vps-deploy/scripts/setup-vps.sh -o setup-vps.sh
less setup-vps.sh          # اقرأه قبل ما تشغّله
bash setup-vps.sh deploy   # ينشئ user "deploy"
```
[setup-vps.sh](../scripts/setup-vps.sh): updates · user · Docker · UFW (SSH فقط) · swap 2 GB.

## Step 2 — Deploy

```bash
ssh deploy@VPS_IP
git clone https://github.com/wesamkhateeb98-creator/postgresql-zero-to-hero.git /opt/pg
cd /opt/pg
cp .env.example .env
sed -i "s/change_me_app/$(openssl rand -hex 24)/" .env
docker compose up -d
docker compose ps          # pg → healthy
```

⚠️ هاد الـ compose تبع **التعلّم**. لـ app حقيقي:

| Learning compose | Production |
|---|---|
| mount `datasets/shop.sql` (1M row وهمي) | شيل الـ mount |
| mount `./:/repo` (فيه `.env`) | شيله |
| App بيتصل كـ `app` (superuser) | role بدون superuser ([07](../../07-ops-scaling/docs/01-roles-rls.md)) |
| `log_min_duration_statement=500` | خليه ✅ |

## Step 3 — Connect من جهازك

```bash
ssh -N -L 5432:127.0.0.1:5432 deploy@VPS_IP     # terminal 1
psql -h localhost -U app -d shop                 # terminal 2
```

```mermaid
sequenceDiagram
    participant L as Laptop :5432
    participant S as SSH :22
    participant PG as VPS 127.0.0.1:5432
    L->>S: encrypted tunnel
    S->>PG: local connection
```

## VPS Sizing

| Workload | vCPU / RAM | `shared_buffers` |
|---|---|---|
| Learning | 1 / 2 GB | 512MB |
| Small app | 2 / 4 GB | 1GB |
| Production | 4 / 8 GB+ | 2GB |

## Update

```bash
cd /opt/pg && git pull && docker compose up -d   # يعيد إنشاء اللي تغيّر فقط
```

Next → [02-security](02-security.md)
