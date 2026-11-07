# Instruções de Uso do Chat para o Projeto ServiceHub

Este documento serve como referência rápida para o desenvolvimento do ServiceHub.

## Como solicitar alterações

- Envolva solicitações de implementação entre `<USER_REQUEST>` quando possível.
- Informe arquivo, comportamento esperado e restrições.
- Antes de criar uma funcionalidade, verifique se já existe fluxo equivalente.

## Regras do projeto

- Estacionamento, locação veicular e guia turístico são módulos equivalentes do hub.
- Cada módulo possui tabelas, regras e telas próprias; o tenant apenas centraliza a conta.
- Não desativar nem duplicar o módulo de estacionamento existente.
- Atualizar contratos de API, documentação, migrations e seeds quando necessário.
- Não versionar `build/`, `.dart_tool/`, `Pods/`, `__pycache__/` ou `.env`.
- Validar com `flutter analyze`, `flutter test` e testes da API antes do commit.

## Fluxo de trabalho

1. Revisar o fluxo ponta a ponta.
2. Localizar código existente e evitar duplicação.
3. Implementar em branch específica.
4. Atualizar documentação e contratos.
5. Executar validações.
6. Commitar e publicar a branch.
