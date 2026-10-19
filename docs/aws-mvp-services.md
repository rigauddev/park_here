# Serviços AWS para homologação do MVP

- **Lightsail**: VPS econômica para Docker, API, web e banco local durante a
  homologação. Configurar backup/snapshot e alertas de orçamento antes de uso
  público.
- **SES**: envio de MFA e e-mails transacionais. A conta começa em sandbox;
  nesse modo somente destinatários verificados recebem mensagens. Solicitar
  produção depois de configurar domínio, SPF, DKIM e DMARC.
- **SNS ou Firebase Cloud Messaging**: push para o aplicativo. O backend pode
  manter tokens por usuário e publicar lembretes de pré-reserva/check-in.
  SNS é uma alternativa AWS com suporte a endpoints móveis; FCM costuma ser a
  opção mais simples para Flutter.
- **SQS/EventBridge (fase posterior)**: fila para notificações e webhooks, sem
  bloquear a requisição de reserva.

No MVP, manter banco e arquivos na VPS com backup testado. Separar secrets em
variáveis de ambiente/secret manager quando sair da homologação. Push e SES
exigem consentimento, opt-out e registro de eventos.
