# Orientacoes Para Agentes IA

Use este arquivo como entrada rapida antes de alterar o ParkHere.

## Contexto

ParkHere e um SaaS/app de gestao e reserva de estacionamentos. O MVP tem backend FastAPI e app Flutter. O produto deve ser multi-tenant para estacionamentos e simples para motoristas.

## Skills Locais

- `agents/skills/parkhere-product-owner`: transformar ideias em requisitos, regras e criterios de aceite.
- `agents/skills/parkhere-backend-api`: evoluir API FastAPI, modelos, migrations e contratos.
- `agents/skills/parkhere-flutter-app`: evoluir telas, providers, modelos e UX Flutter.
- `agents/skills/parkhere-qa-reviewer`: revisar riscos, testes e cenarios de validacao.

## Regras De Trabalho

- Ler `docs/product-overview.md`, `docs/features.md` e `docs/architecture.md` antes de criar modulo novo.
- Manter check-in/checkout por placa e reconhecimento facial como V2.
- No MVP, usar validacao manual/app/portaria e projetar extensibilidade por metodo.
- Nao versionar `build/`, `Pods/`, `.dart_tool/`, `__pycache__/` ou `.env`.
- Antes de concluir mudancas, rodar validacoes possiveis: `flutter analyze`, `flutter test`, testes backend ou ao menos import/build local.

