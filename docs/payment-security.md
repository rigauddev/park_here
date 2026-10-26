# Segurança de pagamentos e permissões

## Checkout Transparente

- O cliente nunca envia PAN ou CVV à API ParkHere; o SDK do Mercado Pago gera o token.
- O backend cria o pedido com `X-Idempotency-Key`, grava apenas o identificador do pedido e reconcilia o resultado pelo webhook.
- A confirmação de pagamento não é confiada ao app: status aprovado deve vir do Mercado Pago.
- Access token e segredo do webhook ficam somente no ambiente do backend. Não aparecem em logs, respostas ou armazenamento local.
- Toda transação mantém `external_reference`, finalidade e snapshot das taxas para auditoria.

## Perfis

Perfis `system` são administrados por superadministradores e controlam a equipe
ParkHere. Perfis `partner` são administrados pelo gestor do parceiro e só podem
controlar operadores do próprio tenant. A API valida escopo, tenant e soft delete.

## Revisão de fluxo

Login, reserva, check-in, checkout e pagamento devem retornar mensagens amigáveis
pela central de feedback. Logs técnicos ficam no servidor. Token expirado encerra
a sessão e não repopula senha ou MFA no formulário.
