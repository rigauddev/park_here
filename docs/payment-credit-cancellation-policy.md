# Pagamentos, Cancelamento E Credito

## Decisao Para O MVP

Usar pagamento unico por reserva e manter um ledger interno de carteira do usuario. A integracao real deve usar Mercado Pago em modelo marketplace/split quando as contas dos parceiros estiverem conectadas.

Fontes oficiais consultadas em 2026-08-14:

- Mercado Pago Split de Pagamentos 1:1: https://www.mercadopago.com.br/developers/pt/docs/split-payments/split-1-1/overview
- Integracao marketplace com OAuth por vendedor: https://www.mercadopago.com.br/developers/pt/docs/split-payments/split-1-1/integration-configuration/integrate-marketplace
- Reembolsos e cancelamentos: https://www.mercadopago.com.br/developers/pt/docs/subscriptions/additional-content/cancellations-and-refunds
- Cartoes salvos e token com CVV no pagamento: https://www.mercadopago.com.br/developers/pt/docs/checkout-api-orders/saved-cards

## Pre-Reserva E Confirmacao

1. Usuario escolhe estacionamento, vaga/tipo, periodo e servicos.
2. Backend calcula rota estimada, tarifa do parceiro e taxa ParkHere.
3. Pre-reserva recebe expiracao: `tempo_de_trajeto + tolerancia_do_parceiro`.
4. A tolerancia deve ser cadastrada pelo parceiro, inicialmente entre 5 e 10 minutos.
5. App mostra alerta de atraso quando o tempo restante estiver perto do fim.
6. Usuario confirma a reserva pagando.
7. Pagamento aprovado muda status para `confirmed` e bloqueia a vaga.
8. Depois de confirmada, a reserva nao expira por trajeto; check-in pode ocorrer dentro do horario de funcionamento e regras de permanencia.

## Cartao, CVV E Pix

- ParkHere nao armazena CVV.
- Cartao salvo deve guardar apenas bandeira, final, apelido e token/cofre do provedor quando disponivel.
- No pagamento, o app deve pedir CVV/3DS quando o Mercado Pago exigir para gerar token de seguranca.
- Para Pix, a reserva so deve ser confirmada apos pagamento aprovado. Nao existe cobranca posterior automatica igual a cartao tokenizado.
- Cobranças futuras de taxa de cancelamento no cartao dependem de regra do provedor, aceite claro do usuario e autorizacao/token adequado. No MVP, preferir cobrar tudo no momento da confirmacao e usar reembolso parcial ou credito.

## Cancelamento

Tipos:

- Cancelamento sem taxa: dentro da janela configurada pelo parceiro e pela plataforma.
- Cancelamento com taxa: fora da janela gratuita ou conforme politica aceita no check-in/reserva.
- No-show: usuario nao compareceu dentro das regras do estabelecimento.

Calculo inicial:

```text
credito = valor_pago - taxa_cancelamento_parceiro - taxa_cancelamento_parkhere
```

Exemplo:

```text
Reserva: R$ 20,00
Taxa estacionamento: R$ 5,00
Taxa ParkHere: R$ 1,00
Credito carteira: R$ 14,00
```

## Carteira E Responsabilidade Do Saldo

O saldo de credito deve ser tratado como passivo da ParkHere ate ser consumido ou reembolsado. Nao devemos retirar esse valor de outro parceiro sem rastreio.

Regras de ledger:

- Criar lancamento `credit.created` no cancelamento.
- Criar lancamento `credit.applied` quando o usuario usar credito em nova reserva.
- Criar lancamento `credit.refunded` se houver devolucao via provedor.
- O comprovante da nova reserva deve mostrar `credito aplicado`.
- O repasse do parceiro deve mostrar valor bruto da reserva, credito aplicado, valor pago em dinheiro e valor a repassar.

Quando credito for usado:

1. Usuario paga somente a diferenca, se houver.
2. Parceiro recebe conforme valor liquido combinado da reserva.
3. ParkHere cobre a parte do credito a partir do saldo/passivo registrado.
4. Conciliacao financeira indica que o valor veio de credito de cancelamento, nao de uma cobranca nova do usuario.

## Mercado Pago

Fluxo alvo:

1. Parceiro conecta conta Mercado Pago via OAuth.
2. Backend cria pagamento com valor total da reserva.
3. Split 1:1 separa valor do vendedor e `marketplace_fee` da ParkHere.
4. Webhook confirma aprovacao, rejeicao, cancelamento ou reembolso.
5. Cancelamentos usam cancelamento/reembolso total ou parcial pela API quando aplicavel.
6. Quando a regra comercial optar por credito interno em vez de reembolso, o ledger ParkHere registra o saldo e o comprovante deixa isso explicito.

## Tarefas Tecnicas

- Criar tabelas `wallet_credits` e `wallet_ledger_entries`.
- Criar politica de cancelamento por parceiro: prazo gratuito, taxa fixa, taxa percentual e teto.
- Criar politica ParkHere de taxa de cancelamento por tipo de servico.
- Criar endpoint `POST /reservations/{id}/confirm-payment`.
- Criar endpoint `POST /reservations/{id}/cancel`.
- Criar job para expirar pre-reservas nao confirmadas.
- Criar alertas de atraso no app.
- Criar comprovante com taxa do parceiro, taxa ParkHere, credito aplicado e split planejado.
