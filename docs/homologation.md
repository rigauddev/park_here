# Homologacao de baixo custo

## Preparar o VPS

Gere um arquivo local com credenciais fortes e limite de acesso ao piloto:

```bash
python3 scripts/create_homolog_env.py \
  --domain app.seudominio.com \
  --allowed-ip SEU_IP_PUBLICO/32
```

O arquivo `.env.homolog` nao deve ser versionado. Aponte o DNS do dominio para o VPS e abra apenas as portas 22, 80 e 443 no firewall.

## Subir API e web

Compile o Flutter diretamente no diretorio servido pelo Caddy:

```bash
flutter build web --release \
  --dart-define=API_URL=https://app.seudominio.com/api \
  --output=deploy/web
docker compose --env-file .env.homolog -f compose.homolog.yml up -d --build
```

O Caddy obtem e renova o certificado HTTPS. A API fica disponivel em `/api` e o MySQL nao e publicado externamente.

## Backup e restauracao

```bash
PARKHERE_COMPOSE_FILE=compose.homolog.yml \
PARKHERE_ENV_FILE=.env.homolog \
bash scripts/backup_database.sh backups/parkhere-$(date +%F).sql.gz

PARKHERE_COMPOSE_FILE=compose.homolog.yml \
PARKHERE_ENV_FILE=.env.homolog \
bash scripts/check_backup_restore.sh backups/parkhere-AAAA-MM-DD.sql.gz
```

Execute a verificacao de restauracao antes do piloto e mantenha ao menos duas copias fora do VPS.
