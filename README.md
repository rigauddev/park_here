# ParkHere

ParkHere e um gestor de estacionamentos e servicos adicionais. O MVP conecta motoristas a estacionamentos com vagas disponiveis, permite pre-reserva enquanto o usuario se desloca, reserva com plano de pagamento, contratacao de servicos extras e check-in/checkout validado no fluxo do app ou pela portaria.

## Estado Atual

- `parkhere_backend/`: API FastAPI com base multi-tenant, cadastro de estacionamento, usuarios, login e MFA em evolucao.
- `parkhere_user_app/`: app Flutter do motorista com mapa, busca, filtros, reserva, pagamento simulado, rota, check-in e checkout.
- `agents/skills/`: skills locais para agentes IA ajudarem no produto, backend, Flutter e QA.
- `docs/`: documentacao funcional, arquitetura, roadmap, fluxo de Git e prompts master.

## MVP

O MVP deve priorizar:

1. Busca de estacionamentos por localizacao, filtros e disponibilidade.
2. Reserva/pre-reserva com expiracao baseada no tempo de rota.
3. Planos por hora, diaria e mensal.
4. Servicos adicionais no ato da reserva: lava-jato, guia turistico e transporte.
5. Check-in e checkout manual/app/portaria.
6. Painel/API para estacionamento gerenciar vagas, reservas e operadores.
7. Pagamento integrado ao backend, inicialmente com provedor unico.

Reconhecimento facial e leitura de placa ficam para V2, mas os modelos e eventos devem nascer preparados para diferentes metodos de validacao.

## Como Rodar

Stack completa com API, MySQL e web Flutter:

```bash
docker compose up --build
```

Backend isolado:

```bash
cd parkhere_backend
docker compose up --build
```

App Flutter:

```bash
cd parkhere_user_app
flutter pub get
flutter run
```

App Flutter web via Docker, isolado:

```bash
cd parkhere_user_app
docker compose up --build
```

## Documentacao

- [Visao do Produto](docs/product-overview.md)
- [Funcionalidades](docs/features.md)
- [Arquitetura](docs/architecture.md)
- [Roadmap](docs/roadmap.md)
- [Fluxo de Git](docs/git-flow.md)
- [Agentes e Skills](docs/agents-and-skills.md)
- [Gestao de Parceiros](docs/partner-management.md)
- [Estrategia de Repositorios](docs/repo-split-strategy.md)
- [Prompts Master](docs/prompts/master-prompts.md)
