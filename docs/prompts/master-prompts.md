# Prompts Master

## Produto

```text
Use $parkhere-product-owner.
Contexto: ParkHere e um gestor de estacionamentos e servicos adicionais. O MVP deve permitir busca de vagas, reserva, servicos extras, pagamento, check-in e checkout manual/app/portaria. Leitura de placa e reconhecimento facial sao V2.
Tarefa: transforme a ideia abaixo em requisitos funcionais, regras de negocio, criterios de aceite e impacto no roadmap.
Ideia:
```

## Backend

```text
Use $parkhere-backend-api.
Leia docs/product-overview.md, docs/features.md e docs/architecture.md.
Tarefa: implemente a funcionalidade abaixo no FastAPI seguindo a arquitetura modular do repo. Inclua modelos, schemas, rotas, service, migration Alembic quando necessario e testes ou validacao minima.
Ao concluir, atualize docs/api-contracts.md quando request/response mudar, atualize seed quando houver novo campo/cenario, limpe caches/artefatos que nao devem ser versionados e atualize docs/roadmap quando houver impacto de produto.
Funcionalidade:
```

## Flutter

```text
Use $parkhere-flutter-app.
Leia docs/features.md e docs/architecture.md.
Tarefa: implemente ou ajuste o fluxo abaixo no app Flutter usando Riverpod e a estrutura por features existente. Evite regra de negocio pesada em widgets e mantenha modelos alinhados ao backend.
Ao concluir, rode format/analyze quando possivel, confirme que os modelos batem com docs/api-contracts.md, limpe caches/artefatos que nao devem ser versionados e atualize docs/roadmap quando houver impacto de produto.
Fluxo:
```

## QA/Review

```text
Use $parkhere-qa-reviewer.
Revise a mudanca abaixo no ParkHere como code review. Priorize bugs, regressao funcional, risco de negocio, seguranca, multi-tenancy e testes faltantes. Responda com achados por severidade e recomendacoes objetivas.
Mudanca:
```

## Publicacao Mobile

```text
Leia docs/store-publication-readiness.md e confirme as fontes oficiais atuais da Apple e Google antes de concluir.
Contexto: ParkHere coleta dados de usuario, documentos, veiculos, localizacao, pagamentos, reservas e futuramente podera usar leitura de placa/reconhecimento facial.
Tarefa: revise a funcionalidade abaixo para garantir aderencia a Play Store, App Store, LGPD, permissoes, privacidade, login, recuperacao de senha, MFA, pagamentos e textos PT-BR/EN. Liste ajustes obrigatorios antes de build de loja.
Funcionalidade:
```

## Planejamento De Sprint

```text
Use $parkhere-product-owner e considere as skills $parkhere-backend-api, $parkhere-flutter-app e $parkhere-qa-reviewer.
Monte uma sprint de uma semana para o MVP do ParkHere. Separe tarefas por backend, Flutter, QA e documentacao. Inclua dependencias e ordem recomendada.
```

## Regras obrigatórias de execução

```text
Priorize sempre a experiência mobile e valide também larguras comuns de tablet e web.
Após alterações grandes ou que afetem dependências, rebuildar os containers com docker compose up -d --build.
Quando houver alteração de modelo ou schema, executar as migrations Alembic e confirmar a revisão atual.
Rodar flutter analyze, flutter test e validações do backend antes do commit. Separar commits por bloco funcional.
No MVP da VPS, arquivos e fotos devem ser gravados no volume persistente local do Docker e o caminho relativo salvo no banco; manter a estrutura preparada para futura migração para object storage.
```
