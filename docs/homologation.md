# Homologacao de baixo custo

## Dados de teste reproduziveis

O roteiro funcional e as contas de teste ficam em `docs/manual-tests.md`. Em
uma base local ou de homologacao recém-criada, aplique as migrations e execute
o seed antes de testar:

```bash
docker compose up -d mysql api
docker compose exec -T api alembic upgrade head
docker compose exec -T api python -m app.scripts.seed_mvp_data
```

O seed recria estacionamentos de demonstração, cliente/veículo/cartão, parceiro,
guia, operadores, reservas em estados variados e escalas com turnos abertos e
com operadores. Ele não apaga o volume nem os dados manuais. A matriz e a filial
de Valença usadas nos testes permanecem com os IDs listados no roteiro. Para
homologação remota, mantenha um banco isolado dos dados de desenvolvimento e
faça backup antes de atualizar a carga.

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

Fotos de check-in e checkout ficam no volume Docker `inspection_photos`, em `/app/storage/inspection`. A API remove arquivos com mais de sete dias durante novos envios. Esse volume deve entrar no backup do VPS; o conteúdo não é exposto pelo Caddy.

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
