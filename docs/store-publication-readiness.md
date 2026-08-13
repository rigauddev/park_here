# Publicacao Nas Lojas

Este documento deve ser consultado antes de preparar builds do ParkHere para Play Store e App Store.

## Fontes Oficiais

- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple App Store Connect, envio para revisao: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/overview-of-submitting-for-review
- Apple App Store Connect, classificacao etaria: https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/
- Google Play release: https://play.google.com/console/about/release/
- Google Play Data safety: https://developer.android.com/privacy-and-security/declare-data-use
- Google Play exclusao de conta: https://support.google.com/googleplay/android-developer/answer/13327111
- Android permissions: https://developer.android.com/guide/topics/permissions/overview
- Android core app quality: https://developer.android.com/docs/quality-guidelines/core-app-quality

## Checklist Do ParkHere

- Ter Politica de Privacidade publicada e linkada nas lojas e no app.
- Declarar coleta/uso de dados pessoais: nome, e-mail, telefone, documentos, veiculos, localizacao, pagamentos e historico de reservas.
- Criar fluxo de exclusao de conta no app e link web para solicitacao de exclusao.
- Pedir permissoes somente no momento de uso: localizacao, camera, fotos/arquivos e notificacoes.
- Explicar claramente por que localizacao e necessaria para buscar estacionamentos proximos.
- Para V2 com placa/facial: exigir consentimento explicito, alternativa manual e politica de retencao de biometria/imagens.
- Nao armazenar CVV. Cartao salvo deve guardar apenas dados permitidos/tokenizados.
- Usar dados ficticios em screenshots e contas demo de revisao.
- Manter login, recuperacao de senha e MFA funcionais antes de enviar para revisao.
- Informar conta de teste para revisores quando area logada for obrigatoria.
- Preparar icone, screenshots, descricao, categoria, classificacao etaria e textos localizados PT-BR/EN.
- Gerar Android App Bundle assinado para Play Store.
- Gerar build iOS assinado via Xcode/App Store Connect/TestFlight.
- Garantir que pagamento de servicos fisicos/presenciais use meios adequados ao fluxo de bens/servicos fora do app.
- Validar acessibilidade minima: contraste, texto legivel, toque confortavel e navegacao sem bloqueios.

## Decisoes Para Desenvolvimento

- Todo recurso novo deve declarar quais dados coleta e quais permissoes usa.
- Recursos de localizacao devem funcionar com permissao negada quando possivel, usando busca manual.
- Camera, reconhecimento facial e leitura de placa ficam no roadmap V2 ate termos consentimento, LGPD, fallback manual e auditoria.
- Toda tela de cadastro deve permitir correcao de e-mail antes de criar a conta.
- O app deve permitir recuperacao de senha sem acesso ao restante do sistema durante a troca.
- Taxas da plataforma devem aparecer explicitamente no comprovante da reserva.
