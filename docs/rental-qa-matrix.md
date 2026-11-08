# Matriz de QA — ServiceHub multi-serviço

Esta matriz é a referência de homologação antes de liberar a locação. Os
testes devem ser executados com o seed limpo e com dados criados pela API; não
usar dados fictícios no cliente quando a API estiver indisponível.

## Acesso e escopo

| Perfil | Estacionamento | Locadora | Guia |
| --- | --- | --- | --- |
| Cliente | buscar, reservar, pagar, check-in/out da própria reserva | buscar grupos/planos, reservar, aceitar contrato, check-in/out da própria reserva | visualizar serviços/indicações disponíveis |
| Operador | somente unidade/escala do dia; reservas, mapa e caixa | somente unidade/escala do dia; frota, reservas, check-in/out | sem menu operacional de locadora |
| Gestor parceiro | todas as unidades do tenant; usuários, escalas, financeiro e taxas | frota, grupos, planos, manutenção, multas e equipe | serviços e afiliados do próprio tenant |
| Admin do sistema | parceiros, usuários, taxas, funcionalidades e auditoria globais | mesmos dados por suporte, sem alterar escopo do parceiro sem auditoria | mesmas regras globais |

Critérios: trocar o `tenant_id` no token ou informar uma unidade de outro tenant
deve resultar em `403/404`, sem revelar se o registro existe. Um operador sem
escala vigente deve visualizar apenas perfil, conta e sua escala.

## Fluxos de reserva da locadora

1. Cliente seleciona cidade/locadora, grupo, plano e período; confirma preço
   diário/semanal/mensal e taxas de cliente/parceiro.
2. A API cria `pending`, reserva o veículo e retorna o snapshot de valores.
3. Pagamento simulado muda somente após confirmação; pagamento duplicado deve
   ser idempotente e não duplicar taxa.
4. Cliente ou operador autorizado realiza check-in com quilometragem, fotos e
   itens. O check-in de outra reserva deve retornar `403/404`.
5. Check-out exige check-in, grava quilometragem final, danos/itens e libera o
   veículo. A diferença de quilometragem deve aparecer no detalhe.
6. Gestor/operador registra multa vinculada ao veículo e reserva; cliente vê
   apenas multas de suas reservas.

Casos negativos: período invertido, veículo reservado, grupo bloqueado, plano
de outra locadora, reserva cancelada/completada e check-out sem check-in.

## Fluxos de estacionamento e guia

- Confirmar que a introdução da locadora não altera mapa, categorias, preços,
  check-in/out ou caixa do estacionamento.
- Na mesma conta, alternar matriz/filial e garantir que o menu operacional usa
  o tipo de serviço correto; o operador só vê a unidade em que está escalado.
- Cliente pode indicar guia somente quando o estacionamento aceita afiliados;
  a comissão deve ser calculada no serviço indicado e ficar visível apenas ao
  guia/estabelecimento.

## Mapa e cidade

- Sem cidade escolhida, obter localização e mostrar apenas serviços em até
  10 km; conferir marcador do usuário e distância ordenada.
- Com cidade escolhida, substituir o filtro de proximidade e listar todos os
  serviços ativos da cidade (estacionamento, locadora e guia).
- Testar `Valença`, `Valenca`, cidade sem acento e cidade inexistente. A grafia
  canônica deve ser exibida e uma cidade sem serviço não pode quebrar a tela.
- Serviços sem latitude/longitude devem ser omitidos do mapa, mas continuar
  visíveis em uma lista de localização pendente para correção do gestor.
- Filtrar por cada tipo e limpar o filtro; não manter marcadores do tipo
  anterior nem usar resultados antigos de cache.

## Riscos do seed/homologação

- Seed deve ser idempotente ou recriar o banco antes de rodar; reservas, multas
  e pagamentos não devem nascer automaticamente para não contaminar o teste.
- O cenário precisa conter uma conta multi-serviço, uma locadora isolada, um
  estacionamento isolado, dois guias afiliados e operadores com escalas em
  unidades diferentes.
- Depois de `alembic upgrade head`, verificar que as colunas de frota/documento
  existem antes de iniciar a API. Se o seed falhar parcialmente, interromper
  o teste e corrigir o banco, sem mascarar com dados locais no Flutter.
- Confirmar volumes de documentos/fotos e limpar apenas artefatos temporários;
  não apagar comprovantes de homologação durante um restart comum.

## Evidências obrigatórias

Guardar para cada execução: commit/seed utilizado, perfil, unidade, request e
status HTTP, status final da reserva, valores e fotos/contrato produzidos.
Falhas de permissão e erros da API devem ser registrados no log central com o
`request_id`, sem token ou dados completos de cartão.
