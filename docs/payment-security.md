# Segurança de pagamentos e permissões

## Checkout Transparente

- O cliente nunca envia PAN ou CVV à API ParkHere; o SDK/hosted fields do Mercado Pago gera o token.
- A carteira exibe somente bandeira, nome, validade e últimos quatro dígitos. O PAN completo não deve ser salvo pela ParkHere.
- O CVV pode ser solicitado no momento da autorização, mas é dado transitório: deve ser apagado imediatamente após a tentativa e nunca pode ser comparado ou recuperado depois.
- O backend cria o pedido com `X-Idempotency-Key`, grava apenas o identificador do pedido e reconcilia o resultado pelo webhook.
- A confirmação de pagamento não é confiada ao app: status aprovado deve vir do Mercado Pago.
- Access token e segredo do webhook ficam somente no ambiente do backend. Não aparecem em logs, respostas ou armazenamento local.
- Toda transação mantém `external_reference`, finalidade e snapshot das taxas para auditoria.

### Por que não guardar o CVV

Guardar o CVV para comparar em transações futuras não é uma opção de segurança.
O PCI SSC classifica CVV/CVC como dado de autenticação sensível e proíbe sua
retenção após a autorização, mesmo criptografado e mesmo com autorização do
cliente ([FAQ 1319](https://www.pcisecuritystandards.org/faqs/1319/),
[FAQ 1574](https://www.pcisecuritystandards.org/faqs/1574/)). A validação é feita
pelo adquirente/emissor durante cada autorização.

### Plano de implementação

1. O app abre o componente oficial do Mercado Pago e coleta o CVV somente para a transação atual.
2. O componente gera um token de cartão; o backend recebe apenas o token, o pedido e a referência do cartão.
3. A carteira persiste apenas `provider_card_id`/tokenização autorizada pelo Mercado Pago, bandeira, últimos quatro dígitos, nome e validade. O token deve ficar protegido no backend e nunca em `SharedPreferences`.
4. O backend cria a ordem com idempotência e o Mercado Pago autoriza. O CVV é descartado tanto no app quanto no servidor.
5. Para recorrência, usa-se credencial/token de cartão armazenado pelo provedor; não se solicita nem armazena CVV para cobranças recorrentes.
6. Antes da produção, revisar escopo PCI, antifraude, 3-D Secure, política de retenção, exclusão da carteira e fluxo de contestação com Mercado Pago e um assessor de compliance.

O fluxo mobile recomendado pelo Mercado Pago é: backend cria uma Order em modo
`manual` com `processing_mode=manual`, `total_amount`, `items`, `payer` e
`X-Idempotency-Key`; o app recebe somente `orderId` e `clientToken`; o SDK
`CardTransaction` tokeniza e processa o cartão contra essa Order. A ParkHere
deve implementar o SDK nativo por plataforma antes de chamar o pagamento real.
Referência: [Cartões em aplicações mobile](https://www.mercadopago.com.br/developers/pt/docs/checkout-api-orders/payment-integration/mobile/cards).

## Perfis

Perfis `system` são administrados por superadministradores e controlam a equipe
ParkHere. Perfis `partner` são administrados pelo gestor do parceiro e só podem
controlar operadores do próprio tenant. A API valida escopo, tenant e soft delete.

## Revisão de fluxo

Login, reserva, check-in, checkout e pagamento devem retornar mensagens amigáveis
pela central de feedback. Logs técnicos ficam no servidor. Token expirado encerra
a sessão e não repopula senha ou MFA no formulário.
