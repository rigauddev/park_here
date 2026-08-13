# Arquitetura

## Estrutura Atual

```text
parkhere_backend/
  app/
    core/          # config, seguranca, database, email, sms, MFA
    db/            # base SQLAlchemy
    modules/
      auth/        # cadastro/login/MFA
      tenants/     # estacionamentos como tenants
      users/       # usuarios e papeis
  alembic/         # migrations

parkhere_user_app/
  lib/
    core/          # tema, rotas, servicos compartilhados
    features/
      auth/
      parking_search/
      reservation/
      payments/
      checkin_checkout/
```

## Backend

Stack atual:

- FastAPI.
- SQLAlchemy async.
- Alembic.
- MySQL.
- JWT/MFA em evolucao.

Modulos recomendados para o MVP:

- `parkings`: unidade, endereco, geolocalizacao, capacidade, status.
- `parking_spots`: vagas fisicas/logicas, tipo e disponibilidade.
- `pricing`: planos, regras por hora/diaria/mensal.
- `services`: servicos adicionais e precos.
- `partners`: cadastro de estabelecimentos parceiros, tipo de servico, status documental e vistoria.
- `partner_documents`: documentos pessoais, alvara, comprovantes e anexos.
- `platform_fees`: taxas por categoria, servico, parceiro ou plano.
- `promotions`: divulgacao de hoteis, restaurantes, turismo e ofertas locais.
- `reservations`: pre-reserva, reserva, expiracao, cancelamento.
- `sessions`: check-in, checkout, eventos e valores finais.
- `payments`: transacao, status, provedor e conciliacao.
- `incidents`: ocorrencias reportadas pelo usuario ou operador.

## App Flutter

Padrao atual:

- Riverpod para estado.
- Features por dominio.
- Services locais para API/calculo.
- Modelos por feature.

Direcao:

- Tela inicial deve ter seletor de idioma PT-BR/EN e escolha Cliente/Parceiro.
- Trocar mocks por chamadas API mantendo os mesmos modelos quando possivel.
- Centralizar contratos JSON no `ApiService`.
- Manter regras puras em services testaveis.
- Evitar regras de negocio irreversiveis em widgets.

## Eventos De Dominio

Eventos importantes:

- `reservation.created`
- `reservation.expired`
- `reservation.confirmed`
- `checkin.requested`
- `checkin.validated`
- `checkout.requested`
- `checkout.completed`
- `payment.authorized`
- `payment.failed`
- `spot.availability_changed`

Projetar V2 para novos metodos de validacao:

- `manual`
- `app_qr`
- `gate_operator`
- `license_plate`
- `face_recognition`

## Dividas Tecnicas Observadas

- `AuthService` usa funcoes/imports que nao aparecem no arquivo lido (`select`, `verify_password`, criacao/verificacao de tokens, `jwt`, `settings`, `SMSService`).
- `verify_mfa` no router passa um objeto `MFARequest`, mas o service espera `mfa_token` e `code`.
- Campo `firt_name` parece typo de `first_name`; corrigir exige migration cuidadosa.
- `current_user.role != "PARKING_ADMIN"` compara enum/string de forma possivelmente incorreta.
- App Flutter ainda usa mocks para estacionamentos e pagamento.
- Ha arquivos gerados no workspace atual (`build/`, `Pods/`, `__pycache__`) que nao devem entrar em Git.

## Estado Atual Da Gestao

Implementado parcialmente:

- Backend possui `tenants`, `users`, papel `PARKING_ADMIN` e cadastro inicial de estacionamento em `/auth/register-parking`.
- Backend possui `parkings` e `parking_services` para listar estacionamentos e servicos no app.
- Seed cria admin de estacionamento, cliente, estacionamentos, servicos e carteira de teste.

Ainda falta:

- App/painel de parceiro.
- Cadastro de parceiro por tipo de servico.
- Upload/gestao de documentos.
- Fluxo de vistoria.
- Gestao de taxas administrativas.
- Divulgacao de hoteis, restaurantes e turismo.

## Endpoints Separados

Direcao definida:

- Cliente: `/customers/signup`, carteira, veiculos, documentos do motorista e reservas.
- Parceiro: `/partners/signup`, perfil do estabelecimento, documentos, vistoria, servicos, taxas e divulgacao.
- Auth: `/auth/login`, MFA e emissao de tokens.
