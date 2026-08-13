# Estrategia De Repositorios E Documentacao

## Contexto

Hoje o projeto esta em uma pasta unica com backend, app Flutter, documentacao e skills. Isso facilita o MVP porque produto, API e app ainda mudam juntos.

## Quando Criar PRs Separadas

Quando houver repos separados:

- Backend: PR apenas com `parkhere_backend/` e docs tecnicas de API.
- Frontend/app: PR apenas com `parkhere_user_app/` e docs de UX/app.
- Produto/docs compartilhadas: PR em um terceiro repo de documentacao ou em uma pasta comum versionada como submodule/subtree.

## Onde Ficam As Docs

Recomendacao:

- Manter `docs/` na raiz enquanto for monorepo.
- Se separar backend e frontend, criar um repositorio `parkhere-docs` para:
  - product overview
  - roadmap
  - arquitetura geral
  - regras de negocio
  - contratos entre app e API
  - prompts/skills de agentes
- Duplicar nos repos separados apenas o que for operacional:
  - backend: `docs/api.md`, migrations, variaveis, endpoints.
  - frontend: `docs/app-flows.md`, telas, build, testes.

## Fluxo Recomendado Agora

1. Continuar com docs na raiz.
2. Criar PR de backend com arquivos de backend e PR draft referenciando docs raiz.
3. Criar PR de frontend com arquivos de Flutter e PR draft referenciando docs raiz.
4. Quando os repos forem separados, mover `docs/` para um repo proprio.

