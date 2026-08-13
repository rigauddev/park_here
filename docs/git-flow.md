# Fluxo De Git

## Branches

- `main`: codigo estavel.
- `develop`: integracao do MVP.
- `feature/<area>-<descricao>`: novas funcionalidades.
- `fix/<area>-<descricao>`: correcoes.
- `docs/<descricao>`: documentacao.

Exemplos:

```bash
git checkout -b feature/backend-reservations
git checkout -b feature/flutter-payment-flow
git checkout -b fix/auth-mfa-login
```

## Commits

Use commits pequenos e explicitos:

```text
feat(api): add parking reservation model
fix(auth): align mfa verification contract
docs(product): add mvp roadmap
test(flutter): cover checkout calculator
```

## Antes De Abrir PR

- Backend: rodar testes/imports e revisar migrations.
- Flutter: rodar `dart format`, `flutter analyze` e `flutter test`.
- Docs: atualizar `docs/features.md` e `docs/architecture.md` quando mudar fluxo.
- QA: revisar criterios de aceite e riscos.

## Primeiro Commit Recomendado

Depois de revisar o que sera rastreado:

```bash
git status --short
git add .gitignore README.md AGENTS.md docs agents parkhere_backend parkhere_user_app
git commit -m "chore: initialize parkhere workspace"
```

