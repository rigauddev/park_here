# QA do módulo de locação veicular

## Fluxo de homologação

1. A conta do parceiro pode conter uma ou mais unidades de serviço; `tenant_id`
   continua sendo o escopo comum e `RentalCompany` identifica a unidade de
   locação. O estacionamento não compartilha tabelas de frota.
2. O cliente escolhe a unidade, grupo/plano e veículo disponível, informa o
   período e cria uma reserva `pending` com snapshot de preço e taxas.
3. O gestor/operador acompanha reservas do próprio tenant. O cliente só vê as
   próprias reservas. O veículo passa a `reserved` e volta a `available` no
   checkout.
4. O check-in registra quilometragem, fotos e itens contratados; o checkout
   exige check-in, registra vistoria final e eventual `damage_fine`.
5. Multas são vinculadas à reserva e ao veículo. Manutenções ficam em tabela
   própria, com próxima revisão e quilometragem.

## Casos automatizados

`tests/test_rental_module_contracts.py` protege os contratos de cadastro,
identificadores legais, normalização de fotos/especificações nulas, período de
reserva e limite de fotos de vistoria.

## Lacunas conscientes para o próximo bloco

- A consulta diária automática de multas e o disparo de e-mail ainda precisam
  de um worker agendado e integração com fonte externa; a API já registra a
  multa manualmente associada à reserva.
- Alertas de seguro, CRLV e manutenção devem usar datas persistidas e um
  scheduler. Não devem ser simulados no cliente.
- O pagamento real e a confirmação de reserva continuam no serviço central de
  pagamentos; `payment_status` permanece `pending` até a confirmação oficial.
- A interface do cliente e a interface operacional devem reutilizar os mesmos
  grupos/planos, mas ações de edição e exclusão ficam protegidas por papel e
  escopo da unidade.
