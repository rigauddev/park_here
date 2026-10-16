# Contratos De API

Este arquivo registra os payloads que o app Flutter espera do backend. Sempre que endpoint, schema ou campo mudar, atualizar aqui junto com o codigo.

## Dashboard agregado do parceiro

`GET /partners/dashboard` exige um usuário parceiro autenticado e retorna os
dados agregados da empresa, separados por matriz e filiais. Filtros opcionais:
`start=YYYY-MM-DD`, `end=YYYY-MM-DD`, `parking_id` e `service_type` (`parking`,
`guide`, `hotel` ou `all`). O período padrão são os últimos 30 dias.

O retorno contém `summary` (reservas, faturamento pago, ticket médio, unidades e
operadores), `units` (cada unidade com tipo `matriz`/`filial`, vagas e receita),
`service_breakdown`, `modality_breakdown`, `monthly`, `customer_cities`,
`additional_services` (serviços extras cadastrados dentro das unidades, com
descrição, reservas e receita) e `staffing` (operadores, turnos e turnos sem
responsável). A API considera
faturamento somente de reservas com `payment_status=paid` e mantém a separação
por `tenant_id` no servidor. A unidade ativa mais antiga é tratada como matriz
até existir uma hierarquia explícita de unidades.

## Cadastro e validação de parceiro

`POST /partners/signup` recebe `service_type` (`parking`, `car_wash`, `hotel`,
`restaurant`, `tour_guide`, `tourism_company`, `transport` ou `other`),
`company_name`, `document_type` (`cpf` ou `cnpj`), `document_number`,
`responsible_name`, `email` e `password`. Também aceita `phone`,
`has_insurance`, `insurance_provider`, `website` e `documents`. Cada item de
`documents` contém `document_type`, `file_name` e `content_base64`. Para CNPJ
são exigidos alvará e RG ou CNH; para CPF é exigido RG ou CNH; seguro informado
exige o documento da apólice. O cadastro fica pendente de análise e não libera
login até a aprovação da equipe administrativa.

Durante os testes, `POST /auth/email/request-code` gera um token e o código
fixo `000000` é aceito por `POST /auth/email/verify-code`. Esse valor deve ser
substituído por código aleatório enviado por e-mail antes da produção.

`POST /partners/me/documents?document_type=alvara|rg|cnh|insurance_policy` recebe
multipart com o campo `file` para complementação após o cadastro. Para CNPJ,
alvará e RG/CNH são aceitos; para CPF, RG/CNH; seguro usa
`insurance_policy`.
Os arquivos ficam no volume local do backend e o cadastro passa para
`documents_submitted`.

## Aprovação de parceiros

- `GET /admin/platform-fees/partners` inclui `approval_status` e `documents`
  (`id`, `document_type`, `file_name` e `download_path`).
- `PATCH /admin/platform-fees/partners/{tenant_id}/approval` recebe
  `{ "stage": "documents"|"inspection", "decision": "approve"|"reject" }`.
  A aprovação documental avança para `waiting_inspection`; a aprovação da
  vistoria muda para `approved` e ativa o tenant. A reprovação suspende o
  tenant.
- `GET /admin/platform-fees/partners/{tenant_id}/documents/{document_id}`
  devolve o arquivo enviado para análise, somente para administradores.

## Entrada fora do horário

Uma chegada agendada fora do horário configurado não bloqueia a criação da
solicitação. A reserva é criada com `status=pending_operator_approval` e
`notification_status=awaiting_operating_hours_approval`; a vaga fica ocupada
para aquele horário. O pagamento, quando iniciado, permanece em
`paid_pending_approval` até a decisão do estacionamento.

- `POST /reservations/{reservation_id}/arrival-approval` recebe
  `{ "decision": "approve"|"reject" }` e pode ser usado por gestor, operador
  ou administrador do estacionamento. Aprovar confirma a reserva; rejeitar
  cancela a solicitação e libera a vaga.

## Afiliação de guia a estacionamento

- `GET /partners/guide/parkings` lista estacionamentos ativos e o status da
  solicitação do guia (`not_linked`, `pending` ou `approved`).
- `POST /partners/guide/parkings/{parking_id}` cria a solicitação do guia.
- `GET /partners/guide/requests` lista solicitações recebidas pelo parceiro de
  estacionamento.
- `POST /partners/guide/links/{link_id}/approve` recebe
  `{commission_type: "percentage"|"fixed", commission_value: number}` e
  aprova o vínculo. Percentual é limitado a 100; valor fixo representa reais
  por indicação.

## Resumo de pagamento

`GET /payments/reservations/{reservation_id}/quote` retorna `reservation_amount`,
`customer_fee_amount`, `establishment_fee_amount` e `total_amount`. As duas
taxas são configuradas pelo administrador do sistema em
`/admin/platform-fees`; o usuário vê o detalhamento antes de confirmar o
pagamento.

### Carteira no MVP

`GET /customer-assets/payment-methods` lista cartões mascarados do cliente
autenticado. `POST /customer-assets/payment-methods` recebe somente
`method_type` (`credit_card` ou `debit_card`), `brand`, `cardholder_name`,
`last_four`, `expiration_month`, `expiration_year` e `is_default`. Número
completo, CVV e campos extras são rejeitados. A rota só aceita papel `customer`.
`POST /customer-assets/payment-methods/{id}/default` escolhe o cartão padrão e
`DELETE /customer-assets/payment-methods/{id}` remove um cartão pertencente ao
cliente autenticado. A migration `fm1b2c3d4e5f` acrescenta metadados de exibição
à tabela `wallet_payment_methods`.

Os metadados mascarados ficam no banco por conta e sincronizam entre dispositivos.
Esse registro ainda não é um cartão utilizável para cobrança: pagamentos reais
exigem tokenização e armazenamento do token/referência pelo provedor. Não
armazenar PAN completo ou CVV no app ou backend. Chaves Pix de recebimento são
exclusivas da conta de repasse do parceiro; clientes pagam por Pix gerado no
checkout. Cartões adicionados antes deste endpoint existiam apenas no cache do
aparelho e precisam ser cadastrados novamente uma vez; o cache antigo não é
associado automaticamente à conta para evitar migrar metadados entre usuários
que compartilham um dispositivo.

O administrador do sistema gerencia essas regras com `GET /admin/platform-fees`
e `PUT /admin/platform-fees/{service_type}`. Esses endpoints exigem o papel
`SUPER_ADMIN`; gestores de estacionamento e guias não alteram taxas globais.
`GET /admin/platform-fees/overview` apresenta indicadores das empresas,
unidades ativas, usuários e regras dos planos Free/Pro para o painel do admin.

### Gestão administrativa de parceiros, taxas individuais e clientes

Todos os endpoints abaixo exigem `SUPER_ADMIN` e token Bearer.

- `GET /admin/platform-fees/partners` lista empresas (`tenants`), mesmo quando
  ainda não existe `PartnerProfile`, com `tenant_id`, nome/status, categoria e
  aprovação quando disponíveis, usuários associados, unidades, serviços
  ativos, quantidade de operadores e limite permitido. O limite incluído é de
  dois operadores por unidade ativa, acrescido de solicitações de pacotes
  aprovadas.
- O item de parceiro inclui `services`, com serviço/código/preço/status e,
  quando aplicável, a unidade à qual pertence.
- `PATCH /admin/platform-fees/partners/{tenant_id}/services/{service_type}/{service_id}/status`
  recebe `{"is_active": false}` para ativar/desativar serviços existentes dos
  tipos `parking` ou `tour_guide`. A API valida que o serviço pertence à
  empresa do caminho.
- `GET /admin/platform-fees/partners/{tenant_id}/fees` lista taxas globais e
  substituições individuais. Cada item contém `service_type`, modo, valor fixo,
  percentual, mínimo, máximo, `is_active` e `source` (`global` ou `partner`).
  Sem substituição individual, aplica-se a taxa global.
- `PUT /admin/platform-fees/partners/{tenant_id}/fees/{service_type}` grava a
  taxa específica do parceiro usando o payload padrão de taxa:

```json
{
  "service_type": "parking",
  "fee_mode": "hybrid",
  "fixed_amount": 0,
  "percentage": 5,
  "min_fee": 0,
  "max_fee": null,
  "is_active": true
}
```

- `GET /admin/platform-fees/customers?query=...` lista até 500 clientes do app;
  a busca opcional corresponde a nome, e-mail ou telefone.
- `PATCH /admin/platform-fees/users/{user_id}/status` recebe
  `{"is_active": false, "reason": "..."}` para suspender uma conta; o motivo
  (mínimo 5 caracteres) é obrigatório e é enviado ao usuário por e-mail. Para
  reativar, envie `{"is_active": true}`. Não permite alterar o
  superadministrador. Contas suspensas não podem iniciar login nem usar tokens
  previamente emitidos.
- `PATCH /admin/platform-fees/partners/{tenant_id}/status` suspende/reativa a
  empresa. A suspensão exige `reason`, grava auditoria e envia e-mail aos
  usuários ativos do parceiro. A reativação não reativa usuários suspensos
  individualmente.
- `PUT /admin/platform-fees/partners/{tenant_id}/operator-capacity` recebe
  `{"operator_limit": 6}` para definir a cota base manual. Pacotes aprovados
  continuam somados. A listagem separa `base_operator_limit`,
  `approved_extra_operators`, `operator_limit_override` e total efetivo para
  evitar contagem duplicada.
- `GET /admin/platform-fees/partners/{tenant_id}/units/{parking_id}` e `PATCH`
  exibem/alteram nome, endereço, cidade e coordenadas da unidade. A API valida
  que a unidade pertence ao parceiro informado.
- `GET /admin/platform-fees/partners/{tenant_id}/units/{parking_id}/fees`
  retorna a taxa efetiva por tipo de serviço e sua origem (`global`, `partner`
  ou `unit`). A precedência é unidade > parceiro > padrão global.
- `PUT /admin/platform-fees/partners/{tenant_id}/units/{parking_id}/fees/{service_type}`
  grava uma taxa específica da unidade. O cálculo de cobrança da reserva usa a
  mesma precedência para a taxa do estabelecimento.
- `GET /admin/platform-fees/partners/{tenant_id}/features` lista o catálogo
  compatível com o tipo de parceiro: dashboard, gestão de estacionamento,
  mapa/reservas, serviços, equipe, afiliações e caixa básico/Pro. Guias recebem
  dashboard, serviços, afiliações e vagas para serviços adicionais. Cada item
  contém nomes e descrições em português/inglês, acesso, classificação paga ou
  gratuita, `price`, `billing_period`, `billing_prices` e dados de solicitação
  por quantidade.
- `PUT /admin/platform-fees/partners/{tenant_id}/features/{feature_key}` grava
  ativação, classificação como paga, preços em `billing_prices` (`monthly`,
  `annual`, `one_time`) e observações. `monthly` vence em 30 dias, `annual` em
  365 dias e `one_time` em 30 dias após a aprovação administrativa.
- `POST /partners/feature-requests` recebe `feature_key`, `quantity`,
  `billing_period` (`monthly`, `annual`, `one_time`) e `payment_method`
  (`pix`, `credit_card`, `debit_card`). A solicitação registra o preço
  configurado para a modalidade e começa em `pending_payment`.
- `POST /partners/feature-requests/{request_id}/pay` registra o pagamento
  simulado e muda o pedido para `payment_received`.
- `POST /partners/feature-requests/{request_id}/receipt` só aceita pedidos em
  `payment_received`, recebe um arquivo PDF, JPG ou PNG de até 30 MB, altera o status para `pending_review` e guarda o
  arquivo no storage local do backend. `GET /partners/feature-requests` retorna
  as solicitações e seus estados. O meio de pagamento é uma declaração para
  conciliação manual; criação de cobrança e confirmação automática do Mercado
  Pago ainda não estão conectadas.
- `GET /admin/platform-fees/feature-requests` lista pedidos; o superadmin usa
  `PUT /admin/platform-fees/feature-requests/{request_id}/approve` ou
  `/reject` para analisar. A aprovação exige comprovante anexado, libera o
  módulo ou capacidade e grava auditoria. `GET
  /admin/platform-fees/feature-requests/{request_id}/receipt` fornece o
  comprovante apenas ao administrador.
- `GET /admin/platform-fees/operator-packages/requests/{request_id}/receipt`
  permite ao administrador consultar o comprovante de pacote de operadores;
  ambos endpoints limitam o caminho ao diretório de storage do tipo de pedido.
- Um serviço e uma unidade são incluídos por parceiro. Vagas adicionais de
  serviço/unidade são solicitadas em quantidade e aprovadas pela gestão. O
  backend impede exceder a capacidade em estacionamento e nos serviços do
  guia; serviços inativos continuam ocupando vaga. Uma unidade extra mantém a
  regra existente de dois usuários operadores adicionais.
- `GET /partners/me` retorna `features` como mapa por chave, inclusive os
  módulos bloqueados, com `name`, `name_en`, descrições, `is_enabled`,
  `is_paid`, `price`, `billing_period`, `requestable` e `quantity_based`. Inclui
  também `unit_count`, `unit_limit`, `service_count` e `service_limit`.
- Rotas de estacionamento, serviços, equipe, afiliações, mapa, reservas e
  Financeiro Pro verificam entitlements no backend. Reservas também atendem o
  caixa básico, que permanece incluído.
- `GET /partners/financial-report` retorna os dados do relatório Pro e exige
  gestor/admin do parceiro e entitlement `financial_management` habilitado.
  Parceiros sem liberação recebem `403`; a tela não é a única barreira.
- `GET /admin/platform-fees/email-templates` lista modelos em `pt_BR` e `en`.
  `PUT /admin/platform-fees/email-templates/{template_key}/{locale}` atualiza
  nome, assunto e fragmentos HTML. Tipos iniciais: `welcome`, `mfa_code`,
  `user_deactivation`, `partner_deactivation`. Variáveis: `{{name}}`,
  `{{code}}`, `{{reason}}`, `{{company}}`, `{{slogan}}` e
  `{{company_footer}}`. A logo é anexada inline com Content-ID
  `parkhere-logo`; falhas de SMTP não desfazem alterações de conta.
- `GET /admin/platform-fees/audit-logs?limit=100` lista eventos administrativos
  (máximo 500) com autor, alvo, horário e detalhes.

Unidades administrativas atualmente são registros reais da tabela `parkings`;
parceiros de guia e demais categorias permanecem empresas/serviços próprios e
não recebem unidades de estacionamento artificiais. O relacionamento de
afiliação de guias continua limitado ao módulo atual de estacionamento. Antes
de lançar afiliação para hotéis, lava-jatos ou outros serviços, criar um vínculo
genérico entre guia, parceiro e serviço, com comissão por indicação e
aprovação do parceiro.

### Precedência e limites comerciais

Taxas globais são os padrões da plataforma. Uma taxa individual ativa substitui
o padrão para aquele parceiro e tipo de serviço; uma taxa de unidade substitui
as duas anteriores. Os registros ficam em `partner_platform_fees` e
`parking_platform_fees`. A regra comercial planejada para unidades e serviços é
um serviço incluído por parceiro e cobrança para unidades/serviços adicionais;
ela ainda precisa de catálogo de preços, contratação, confirmação de pagamento,
entitlements e auditoria antes de ser aplicada em produção. O limite atual
calculado para operadores é duas vagas por unidade ativa mais quantidades de
pacotes aprovados manualmente.

Guias parceiros usam `GET/POST /partners/guide/services` para cadastrar seus
próprios serviços turísticos, separados das afiliações a estacionamentos.

`POST /partners/parking-map/{parking_id}/slots/{slot_code}/block` alterna o
status operacional da vaga entre bloqueada e disponível. A vaga bloqueada não
é oferecida para novas reservas; o estacionamento permanece ativo e seus
dados históricos são preservados.

## Busca De Estacionamentos

`GET /parkings?city=Valenca`

Query:

```text
city: opcional, minimo 2 caracteres. Filtra por cidade sem diferenciar maiusculas/minusculas.
```

Response:

```json
[
  {
    "id": "parking-id",
    "name": "Estacionamento Central ParkHere",
    "address": "Rua Conselheiro Ferraz, Centro, Valenca - BA",
    "city": "Valenca",
    "lat": -13.3703,
    "lng": -39.0731,
    "availableSpots": 42,
    "pricing": {
      "firstHourPrice": 8.0,
      "additionalHourPrice": 4.0,
      "dailyPrice": 35.0,
      "weeklyPrice": 160.0,
      "monthlyPrice": 280.0
    },
    "rating": 4.8,
    "hasCarWash": true,
    "hasTourGuide": true,
    "hasTransportService": false,
    "hasCoveredArea": true,
    "hasVipSpots": true,
    "carWashPrice": 35.0,
    "tourGuidePrice": 50.0,
    "transportPrice": 0.0
  }
]
```

Observacoes:

- O app pode usar geolocalizacao local para ordenar ou centralizar o mapa.
- A previsao de chegada no app cliente pode ser estimada localmente no MVP.

## Gestao De Estacionamento

`GET /partners/parking-management`

`POST /partners/parking-management`

`PUT /partners/parking-management/{parking_id}`

O endereço de uma unidade é persistido de forma estruturada nos campos
`street`, `number`, `neighborhood`, `city` e `postal_code`. `address` continua
no contrato como representação legada/formatada para compatibilidade com
clientes antigos; novos clientes devem enviar os campos separados.

O request e a resposta de unidade incluem `work_regime`: `commercial`,
`three_shifts`, `24h_on_3off` ou `administrative_8h`. Esse campo descreve a
jornada usada pelo gerador e é separado de `has_24h_gate`, que só informa se a
portaria funciona 24 horas.

Operadores do mesmo tenant podem ser associados a uma ou mais unidades:
`GET/PUT /partners/operators/{operator_id}/parkings` recebe
`{"parking_ids": ["..."]}` e a resposta confirma os IDs persistidos. A tela
carrega os vínculos existentes antes de permitir edição. `GET /partners/operators`
também retorna o CPF cadastrado para consulta; e-mail e CPF aparecem como campos
somente leitura nos detalhes do operador. O gestor cria escalas com
`GET /partners/shifts` e `POST /partners/shifts`, informando `operator_id`,
`parking_id`, `starts_at` e `ends_at`. A API valida que operador e unidade
pertencem à mesma empresa, que o operador está associado à unidade e que ele não
tenha outro turno sobreposto em qualquer unidade (resposta `409`). Datas sem fuso
representam o horário local de Brasília; datas com fuso são convertidas para esse
fuso antes de persistir.

O limite básico de operadores é calculado por serviço operacional ativo: cada
unidade sem serviço cadastrado garante duas vagas; cada serviço ativo da unidade
garante mais duas vagas. Pacotes aprovados pelo administrador são somados ao
limite e não substituem essa capacidade básica.

O mapa operacional (`GET /partners/parking-map`) devolve `category_pricing` e
as tarifas de cada categoria (`uncovered_pricing`, `covered_pricing`). Ao criar
uma reserva operacional, o app apenas envia `spot_type` e `pricing_plan`; o
backend calcula o preço usando a tarifa cadastrada para aquela categoria.

Request:

```json
{
  "name": "Estacionamento Central ParkHere",
  "street": "Rua Conselheiro Ferraz",
  "number": "120",
  "neighborhood": "Centro",
  "postal_code": "45400-000",
  "address": "Rua Conselheiro Ferraz, Centro, Valenca - BA",
  "city": "Valenca",
  "lat": -13.3703,
  "lng": -39.0731,
  "arrival_tolerance_minutes": 5,
  "total_spots": 80,
  "available_spots": 42,
  "covered_spots": 24,
  "uncovered_spots": 56,
  "vip_spots": 3,
  "large_spots": 4,
  "bus_spots": 1,
  "pickup_spots": 4,
  "has_vip_spots": true,
  "has_24h_gate": true,
  "has_security_system": true,
  "wants_automatic_access": false,
  "has_automatic_access": false,
  "uncovered_pricing": {
    "first_hour_price": 8,
    "additional_hour_price": 4,
    "daily_price": 35,
    "weekly_price": 160,
    "monthly_price": 280
  },
  "covered_pricing": {
    "first_hour_price": 10,
    "additional_hour_price": 5,
    "daily_price": 45,
    "weekly_price": 210,
    "monthly_price": 360
  },
  "services": [
    {
      "code": "car_wash",
      "name": "Lavagem simples",
      "price": 35,
      "is_active": true
    }
  ],
  "is_active": true
}
```

Response: mesmo formato, acrescido de `id`.

Regras:

- Endpoint exige usuario parceiro do mesmo `tenant_id`.
- `covered_spots + uncovered_spots` deve bater com `total_spots` no app e no backend.
- `vip_spots`, `large_spots`, `bus_spots` e `pickup_spots` sao configurados pelo parceiro no cadastro do estacionamento.
- A soma dos tipos especiais nao pode passar `total_spots`.
- O mapa operacional usa essas quantidades para classificar as vagas; nao deve criar tipos especiais por regra fixa do numero da vaga.
- `city` e obrigatorio para busca multi-cidade.
- `arrival_tolerance_minutes` define por quanto tempo a vaga fica bloqueada apos a previsao de chegada.

## Mapa Operacional Do Parceiro

`GET /partners/parking-map`

Response:

```json
{
  "parking_id": "parking-id",
  "parking_name": "Estacionamento Central ParkHere",
  "total_spots": 80,
  "available_spots": 42,
  "pre_reserved_spots": 8,
  "occupied_spots": 3,
  "cancelled_spots": 2,
  "pre_reserved_amount": 84.0,
  "confirmed_amount": 126.0,
  "checked_in_amount": 90.0,
  "cancelled_amount": 28.0,
  "pending_payment_amount": 112.0,
  "paid_amount": 188.0,
  "services_amount_by_status": {
    "pre_reserved": 35.0,
    "confirmed": 70.0,
    "checked_in": 0.0,
    "cancelled": 0.0
  },
  "slots": [
    {
      "code": "V003",
      "type": "covered",
      "status": "pre_reserved",
      "reservation": {
        "id": "reservation-id",
        "customer_name": "Cliente ParkHere",
        "customer_phone": "+5575999999999",
        "vehicle_plate": "PKH1A23",
        "vehicle_model": "Chevrolet Onix",
        "status": "pre_reserved",
        "payment_status": "pending",
        "final_total": 42.5,
        "route_minutes": 14,
        "created_at": "2026-08-17T10:22:00",
        "checked_in_at": null,
        "arrival_estimate_at": "2026-08-17T10:36:00",
        "is_manual_arrival": false,
        "checkout_grace_minutes": 15,
        "checkout_excess_minutes": 0,
        "checkout_excess_amount": 0,
        "checkout_excess_paid_at": null
      }
    }
  ],
  "cards": "deprecated; usar campos agregados de valor e quantidade no nivel do estacionamento"
}
```

Regras:

- Parceiro e operador veem apenas reservas do proprio estabelecimento/tenant.
- Reservas de cliente avulso criadas no patio retornam `customer_name="Cliente avulso"`, `vehicle_plate` e `customer_phone` preenchidos pelos campos de portaria.
- O card da vaga deve mostrar a previsao em formato curto, por exemplo `14 min · 10h36`.
- Reserva operacional deve permanecer vinculada ao `spot_code` selecionado no mapa de vagas.
- Reserva cancelada entra nos indicadores de cancelamento, mas nao bloqueia vaga no mapa.
- Vaga pre-reservada deve exibir tempo restante ate `hold_expires_at`.
- Vaga em permanencia deve exibir tempo no patio e, quando houver, minutos/valor de excedente.
- Detalhes da vaga devem mostrar cliente, veiculo, periodo, pagamento, servicos e acoes operacionais permitidas.

## Pre-Reserva E Reserva

`POST /reservations/pre-checkin`

Request:

```json
{
  "parking_id": "parking-id",
  "vehicle_id": "vehicle-id",
  "spot_code": "V003",
  "spot_type": "uncovered",
  "arrival_estimate_at": "2026-08-17T10:36:00",
  "arrival_now": false,
  "walk_in_plate": null,
  "walk_in_phone": null,
  "is_manual_arrival": false,
  "pricing_plan": "hourly",
  "duration_hours": 2,
  "route_minutes": 14,
  "guide_user_id": null,
  "service_codes": ["car_wash"],
  "terms_accepted": true,
  "terms_version": "reservation-terms-2026-09-v1",
  "terms_locale": "pt_BR"
}
```

Response:

```json
{
  "reservation_id": "reservation-id",
  "walk_in_plate": null,
  "walk_in_phone": null,
  "status": "pre_reserved",
  "created_by_name": null,
  "created_by_phone": null,
  "payment_status": "pending",
  "spot_code": "V003",
  "route_minutes": 14,
  "expires_at": "2026-08-17T10:46:00",
  "arrival_estimate_at": "2026-08-17T10:36:00",
  "is_manual_arrival": false,
  "base_amount": 12.0,
  "services_amount": 35.0,
  "platform_fee_amount": 3.0,
  "final_total": 50.0,
  "terms_accepted_at": "2026-08-17T10:22:00Z",
  "terms_version": "reservation-terms-2026-09-v1",
  "terms_locale": "pt_BR",
  "accepted_terms": [
    {"service_type": "platform", "version": "reservation-terms-2026-09-v1", "text": "..."},
    {"service_type": "parking", "version": "reservation-terms-2026-09-v1", "text": "..."},
    {"service_type": "car_wash", "version": "reservation-terms-2026-09-v1", "text": "..."}
  ]
}
```

Regras:

- Backend recalcula valores e nao confia em total enviado pelo app.
- `terms_accepted=true`, `terms_version` atual e `terms_locale` (`pt_BR` ou `en`) sao obrigatorios. Sem aceite a API retorna `422`; se a versão estiver desatualizada retorna `409` para o app exibir novamente os termos.
- O backend persiste timestamp UTC, versão, idioma e snapshot do texto de intermediação, estacionamento e cada serviço selecionado; a resposta inclui `accepted_terms` para auditoria e consulta posterior.
- A versão atual é `reservation-terms-2026-09-v1`. Atualizar versão quando o texto mudar materialmente e atualizar o cliente antes de exigir a nova versão.
- Cliente deve informar `vehicle_id`; parceiro/operador deve informar `walk_in_plate` e `walk_in_phone`.
- Reservas criadas por operador/gestor deixam `user_id` nulo e retornam no
  endpoint operacional `created_by_name`, `created_by_phone` e `customer_phone`;
  o cliente pode ser associado posteriormente por telefone e placa.
- Para reserva criada por operador/parceiro, `arrival_now=true` grava o horario atual no servidor; se for agendada, `arrival_estimate_at` deve vir com timezone ou sera tratado como horario local de `America/Bahia`.
- Expiracao da pre-reserva usa `arrival_estimate_at + arrival_tolerance_minutes`.
- Ao nao informar `spot_code`, o backend escolhe uma vaga livre compativel com `spot_type`.
- Duas reservas simultaneas para a mesma vaga geram uma confirmacao e uma falha `409`.
- Reserva agendada futura deve validar horario de funcionamento, antecedencia maxima e politica de cancelamento antes da confirmacao.
- Politica de cancelamento deve explicitar prazo sem taxa, taxa do estacionamento, taxa ParkHere e regra de credito em carteira.

No check-in do cliente, `POST /reservations/{reservation_id}/checkin` recebe
`latitude` e `longitude` atuais na query. O servidor valida distância máxima de
150 metros do estacionamento e grava o horário e o usuário autenticado que
realizou a ação. Gestores e operadores continuam autorizados para a portaria do
próprio tenant.

Na etapa de escolha do plano, o cliente pode consultar
`GET /parkings/{parking_id}/guides` e enviar opcionalmente o `guide_user_id` como
indicação. Isso é independente do extra pago `tour_guide`: indicar o guia não
contrata um passeio. A lista contém somente guias ativos com afiliação aprovada e
é vazia quando a unidade não aceita afiliados. Se o identificador não pertencer a
uma afiliação aprovada, se o guia não for um parceiro independente ou se a unidade
desativar afiliados, a API rejeita a reserva com `422`.
O backend calcula e congela `guide_commission_amount` na reserva, conforme a
comissão percentual ou fixa configurada pelo parceiro. O campo é uma comissão do
estabelecimento para o guia e não altera o total cobrado do cliente.

`GET /partners/guide/parkings` inclui `accepts_affiliates`, `offer_terms` e o
estado do vínculo. O guia pode solicitar afiliação somente quando
`accepts_affiliates=true`; caso contrário `POST /partners/guide/parkings/{id}`
retorna `409`. Em estacionamento, a adesão e as ofertas são configuradas por
unidade em `PUT /partners/parking-management/{parking_id}/guide-offer`, que aceita
`accepts_affiliates` e `terms` (`daily`, `weekly`, `monthly`, `long_term`). Para
ativar a adesão, todas as quatro modalidades precisam ter comissão positiva.

`GET /partners/guide/parkings` retorna `offer_terms` antes da solicitação de
afiliação, com valores independentes para `daily`, `weekly`, `monthly` e
`long_term`. O parceiro configura esses termos em
`PUT /partners/parking-management/{parking_id}/guide-offer`. Na aprovação, os
termos são copiados para a afiliação e ficam congelados para novas reservas.

**Regra de identidade:** todo parceiro, inclusive guia turístico, tem seu próprio
`tenant_id`, `Tenant` e `PartnerProfile`. A afiliação é uma relação entre o ID do
usuário guia e a unidade/serviço parceiro; nunca se reutiliza o tenant do
estacionamento para representar o guia. O cadastro padrão `/partners/signup` já
cria essa identidade independente. O seed local separa o guia de demonstração do
tenant do estacionamento e preserva os vínculos existentes.

**Extensão para novos módulos:** cada parceiro pode aceitar afiliados; ao publicar
um serviço afiliável, configura nele a modalidade e o valor da comissão (fixo ou
percentual). O serviço/reserva guarda uma cópia imutável da oferta e da comissão
aplicada. Guias solicitam vínculo com o parceiro/serviço, o parceiro aprova e a
indicação somente é contabilizada conforme o estado terminal elegível definido
pelo módulo (no estacionamento, reserva concluída). Hotéis, restaurantes,
lava-jatos, agências, transporte e novos catálogos devem reutilizar esse contrato
genérico por serviço, sem criar um `tenant_id` compartilhado nem acoplar a
indicação à compra de um serviço adicional.

A equipe ParkHere configura a taxa da plataforma em `guide_commission` por
`PUT /admin/platform-fees/guide_commission`. Essa porcentagem incide somente
sobre a comissão bruta do guia. A reserva guarda `guide_commission_amount`,
`guide_platform_fee_amount` e `guide_payout_amount`; esses campos aparecem
apenas nas respostas de gestão do estacionamento e do guia, nunca na resposta
do cliente.

O ranking do guia está em `GET /partners/guide/dashboard` e combina quantidade
de indicações concluídas, média das avaliações e total líquido a receber apenas
de reservas em status `completed`; canceladas/expiradas não geram repasse. A
resposta também separa indicações ainda pendentes de conclusão. O cliente pode
avaliar uma indicação concluída uma única vez em
`POST /partners/guide/reviews/{reservation_id}` com nota de 1 a 5.

## Cancelamento De Reserva

`POST /reservations/{reservation_id}/cancel`

Request:

```json
{
  "reason": "Cliente desistiu antes da chegada"
}
```

Response: `ReservationResponse` com:

```json
{
  "status": "cancelled",
  "cancelled_at": "2026-08-17T11:00:00",
  "cancellation_fee_amount": 1.0,
  "cancellation_credit_amount": 14.0
}
```

Cliente só pode cancelar diretamente a própria pré-reserva não paga (`status=pre_reserved` e `payment_status != paid`). Pagamento confirmado ou reserva confirmada retorna `409` e precisa de solicitação de reembolso; o endpoint atual não solicita nem executa estorno. `cancelled_by_user_id` e `cancelled_by_name` registram quem tomou a ação.

O cliente também precisa cancelar antes de `hold_expires_at`; vencida, a pré-reserva já é encerrada pela API. O app oculta o botão depois do prazo e sempre depende da revalidação do endpoint. Consulte [Ciclo de vida da reserva](reservation-lifecycle.md) para a matriz de estados e permissões.

`PATCH /admin/platform-fees/users/{user_id}/status` desativa ou reativa usuários de cliente e parceiro. Desativar exige motivo, define `is_active=false` e `deleted_at`; reativar limpa a data lógica. Autenticação e listagens operacionais omitem usuários com `deleted_at` preenchido. O painel administrativo mantém o registro visível para auditoria e eventual reativação; suas relações continuam no banco para preservar histórico.

O cliente também precisa cancelar antes de `hold_expires_at`; vencida, a pré-reserva já é encerrada pela API. O app oculta o botão depois do prazo e sempre depende da revalidação do endpoint. Consulte [Ciclo de vida da reserva](reservation-lifecycle.md) para a matriz de estados e permissões.

## Pagamento De Reserva E Excedente

### Compra de funcionalidade

`POST /partners/feature-requests/{request_id}/pay` registra o pagamento
simulado escolhido (Pix, crédito ou débito) e muda o pedido para
`payment_received`. Somente depois disso o botão de comprovante é liberado;
o upload muda o pedido para `pending_review`. Em produção este passo será
substituído pelo retorno/webhook do Mercado Pago.

`POST /payments/reservations/{reservation_id}/intent`

Request:

```json
{
  "method": "pix",
  "purpose": "reservation"
}
```

Para registrar pagamento em dinheiro no caixa:

```json
{
  "method": "cash",
  "purpose": "reservation",
  "cash_received": 20.0
}
```

Para pagar excedente de permanencia no checkout:

```json
{
  "method": "pix",
  "purpose": "checkout_excess"
}
```

Response:

```json
{
  "id": "payment-id",
  "reservation_id": "reservation-id",
  "provider": "mock",
  "is_simulated": true,
  "method": "pix",
  "purpose": "checkout_excess",
  "status": "pending",
  "gross_amount": 5.0,
  "platform_fee_amount": 0.0,
  "partner_amount": 5.0,
  "withheld_fee_amount": 0.0,
  "cash_received": null,
  "provider_fee_estimate": 0.0,
  "checkout_url": "https://www.mercadopago.com.br/checkout/v1/mock?ref=checkout_excess:reservation-id",
  "qr_code": "000201...",
  "external_reference": "checkout_excess:reservation-id",
  "split": [
    {
      "receiver": "parkhere_app",
      "amount": 0.0,
      "description": "Taxa ParkHere excedente"
    },
    {
      "receiver": "mp_seller_parkhere_seed",
      "amount": 5.0,
      "description": "Excedente de permanencia"
    }
  ]
}
```

Regras:

- `purpose=reservation` cobra o valor original da reserva.
- `purpose=checkout_excess` cobra somente o excedente calculado para plano por hora.
- `method=cash` so pode ser criado por parceiro/operador do mesmo tenant e exige `cash_received >= gross_amount`.
- Pagamento em dinheiro confirmado cria debito `partner_fee_debts` com a taxa ParkHere daquela reserva.
- Pagamento online futuro abate debitos pendentes do repasse do parceiro e retorna `withheld_fee_amount`.
- Confirmacao mock e idempotente: repetir `/payments/{payment_id}/confirm` nao duplica debito nem liquidacao.
- Checkout por hora permite tolerancia de 15 minutos apos o tempo contratado.
- Se houver excedente sem pagamento, `POST /reservations/{reservation_id}/checkout` retorna `402` e mantem checkout bloqueado.
- A confirmacao de pagamento do excedente grava `checkout_excess_paid_at` e libera nova tentativa de checkout.
- O app chama primeiro o checkout. Quando a API responde `402`, usa os minutos e valor de excedente calculados no servidor e cria a intenção com `purpose=checkout_excess`; após confirmação, repete o checkout.

Regras:

- Cliente só pode cancelar diretamente pré-reserva não paga. Reserva paga deve passar por pedido de reembolso; o endpoint atual não executa esse fluxo.
- Operador pode cancelar somente pre-reserva ou reserva criada por ele enquanto nao houve check-in.
- Reserva com check-in so pode ser cancelada pelo gestor do parceiro.
- Cancelamento ate 5 minutos apos criacao nao cobra taxa.
- Apos 5 minutos, aplica taxa administrativa ParkHere configurada como `platform_fee.service_type=cancellation`.
- Taxa de cancelamento do parceiro por estacionamento entra no proximo bloco de politica operacional.
- Solicitação de reembolso precisa de recurso persistido, motivo, anexo opcional, transação de pagamento vinculada, cálculo sujeito à política vigente, prazo de três dias úteis e decisão administrativa auditável. Reembolso financeiro automático depende do provedor e não existe no mock. Direitos legais aplicáveis prevalecem sobre taxas configuradas.


## Revisao de servicos e pagamento simulado — 06/09/2026

### Gestao de estacionamento

O request existente de `/partners/parking-management` continua com `services`:
```json
{"services": [{"code": "car_wash", "name": "Lavagem", "price": 30, "is_active": true}]}
```
Demais campos obrigatorios do estacionamento permanecem obrigatorios.
`price` e tarifas por area devem ser finitos e >= 0. Codigo/nome sao aparados e nao
podem ficar vazios. Codigos duplicados no catalogo retornam 422. Latitude/longitude
respeitam os limites geograficos. A resposta de atualizacao inclui o catalogo recem-salvo.
Em `service_codes` da reserva, repeticoes sao consideradas uma unica contratacao.
Nao ha migration nova nesta rodada; snapshots de reservas anteriores sao preservados.

### POST /payments/reservations/{reservation_id}/intent

Request: `{"method":"pix","purpose":"reservation"}`.
`method`: `pix`, `credit_card`, `debit_card`, `cash`; `purpose`: `reservation`, `checkout_excess`.
Resposta mantem todos os campos existentes e adiciona `is_simulated` booleano.
No ambiente de simulacao: `provider="mock"`, `is_simulated=true`, `status="pending"`.
O QR/checkout desse modo sao ficticios e nao devem ser usados para transferencias.
`PAYMENT_PROVIDER` agora tem default `mock`. Configuracao explicita diferente de
`mock` retorna 503: a integracao real ainda nao foi ligada aos endpoints.
Reserva cancelada, concluida ou pre-reserva expirada retorna 409; excedente exige check-in.

### POST /payments/{payment_id}/confirm

Somente transacao `provider=mock` com ambiente `PAYMENT_PROVIDER=mock` pode ser
confirmada manualmente. Demais providers retornam 403. Confirmacao de uma transacao
ja paga e idempotente; transacoes pendentes nao reabrem reservas encerradas.
O app so usa essa confirmacao se o intent informar `is_simulated=true`, e exibe
que nenhuma cobranca real ocorreu. Sem reservation_id, o app retorna erro.
Compatibilidade: transacoes ficticias antigas rotuladas `mercado_pago` nao sao
confirmaveis por este endpoint; criar novo intent mock em reserva elegivel.

Cliente HTTP inicial: [Pix / Payments API oficial](https://www.mercadopago.com.br/developers/pt/docs/checkout-bricks/payment-brick/payment-submission/pix).
A chave `X-Idempotency-Key` e recebida do chamador. O cliente nao faz retentativas
automaticas nem aplica status na reserva. OAuth, persistencia do intent, webhook,
conciliacao e split precisam ser concluidos antes de conectar o transporte as rotas.
## Veiculos Do Cliente

`GET /customer-assets/vehicles` lista os veiculos do usuario autenticado.

`POST /customer-assets/vehicles` recebe `nickname`, `plate`, `brand`, `model`, `color`, `vehicle_document` (PDF), `ownership_type` e `is_active`. Ao ativar um veiculo, os demais ficam inativos.

Pre-reservas usam o tempo estimado da rota mais cinco minutos de tolerancia no MVP. A atualizacao do mapa entre operador e cliente usa o endpoint de mapa com recarga; webhook fica reservado para confirmacao externa do Mercado Pago.

## Tipos de vaga e disponibilidade — 07/09/2026

`GET /parkings` e `GET /parkings/{parking_id}` retornam a quantidade disponivel por categoria:
`coveredSpots`, `uncoveredSpots`, `vipSpots`, `largeSpots`, `pickupSpots`, `motoHomeSpots` e `busSpots`.
Os precos diarios e da primeira hora por area ficam em `coveredDailyPrice`,
`uncoveredDailyPrice` e nos campos correspondentes de `pricing`. O cliente deve
ocultar categorias com quantidade zero e enviar `spot_type` (`covered`, `uncovered`,
`vip`, `large`, `pickup`, `motorhome`, `bus` ou `any`) ao criar a pre-reserva.
O campo `moto_home_spots` foi adicionado ao request de gestao e exige migration
`e7f8a9b0c1d2_add_moto_home_spots`.

O cadastro de estacionamento exige que `total_spots` seja exatamente a soma
das categorias informadas. `category_pricing` permite enviar tarifas próprias
por categoria (`covered`, `uncovered`, `vip`, `large`, `pickup`, `bus`,
`motorhome`), cada uma com primeira hora, hora adicional, diária, semanal e
mensal. A migration `f1a2b3c4d5e6` cria o armazenamento desses preços.

`GET /reservations` retorna o histórico do cliente autenticado, incluindo
pré-reservas expiradas, canceladas, confirmadas, em check-in e concluídas.
Quando uma pré-reserva vence, seu `status` operacional passa para `cancelled`,
`payment_status` fica `expired`, `cancelled_at` e a razão automática são
registrados, e a vaga volta à disponibilidade. O app usa `payment_status` para
apresentá-la como **Expirada**, separando-a visualmente de um cancelamento pelo
usuário.
O retorno inclui `cancelled_by_user_id` e `cancelled_by_name`. O código exibido `PH-XXXXXXXX` é derivado do UUID e não substitui o identificador técnico. `GET /parkings` devolve `category_pricing` para que a escolha da categoria atualize os preços por hora, diária e mensal.

## Carteira e fotos de inspeção — 14/09/2026

Clientes cadastram somente cartões na carteira; pagamentos Pix geram o QR Code
no Mercado Pago durante a reserva. Usuários parceiros cadastram apenas a chave
Pix de recebimento na conta de repasse.
Os metadados de exibição dos cartões de clientes ficam no backend e acompanham a
conta entre dispositivos. `SharedPreferences` é somente cache local. PAN completo
e CVV não são armazenados nem enviados pela carteira. Cartões adicionados neste
MVP são perfis mascarados para teste e não autorizam pagamento real; isso depende
da integração de tokenização do Mercado Pago. Cartão salvo pelo provedor deverá
ser cobrado por referência/token e solicitar o CVV novamente quando necessário.

O endpoint `GET /reservations/{reservation_id}/photos` lista os metadados das fotos de inspeção disponíveis para o cliente ou equipe autorizada.

O endpoint `POST /reservations/{reservation_id}/photos?kind=...` aceita fotos do
check-in e checkout. O envio do checkout usa os mesmos tipos (`front`, `rear`,
`left`, `right`) e substitui o arquivo anterior da reserva. Os arquivos ficam
em armazenamento local temporário por sete dias e são removidos na próxima
limpeza do endpoint.

## Jornada e escalas — 10/09/2026

- `GET /partners/work-profiles` lista a jornada cadastrada por operador e unidade.
- `PUT /partners/work-profiles` recebe `operator_id`, `parking_id`, `daily_hours`,
  `lunch_minutes` e `days_off` (dias da semana, 0=domingo).
- `GET /partners/schedule-history` retorna alterações de jornada para auditoria.
  A escala deve ser gerada somente para operadores associados à unidade.
- `POST /partners/shifts/suggest` recebe `parking_id`, `operator_ids`, `starts_on`,
  `ends_on`, `daily_hours` e `work_regime`; `opening_time` e `closing_time` opcionais são usados
  quando a unidade ainda não possui grade semanal configurada. Retorna turnos rotativos, folgas sugeridas,
  `required_people` e `coverage_warning`. A sugestão é editável antes de gravar.
  `operator_id` pode ser nulo: nesse caso o turno fica como vaga aberta para
  atribuição posterior, sem bloquear a criação da escala.
  `three_shifts` gera três faixas de 8h a cada dia (deixa faixas sem operador
  abertas); `24h_on_3off` agenda plantão de 24h com ciclo de três dias de folga;
  `administrative_8h` gera jornadas limitadas a oito horas; `commercial` segue
  os horários semanais da unidade e pode sobrepor faixas para evitar intervalo
  descoberto. A API não exige que todos os turnos tenham operador.
  Operadores que já tenham escala no período em outra unidade não entram na
  sugestão e aparecem em `conflicting_operator_ids`; a gravação também bloqueia
  sobreposição para proteger a regra mesmo se a escala for alterada em paralelo.
  O gerador consulta `operating_hours` da unidade por dia da semana, ignora dias
  fechados e limita o turno ao fechamento configurado.
- `DELETE /partners/shifts/{shift_id}` cancela um turno e grava a alteração no
  histórico de auditoria.
- `PUT /partners/shifts/{shift_id}` atribui/troca o operador e permite ajustar
  início e fim. Body: `operator_id` (UUID ou `null` para deixar o turno aberto),
  `starts_at`, `ends_at`. O operador precisa estar ativo e associado à unidade;
  sobreposição de horário em qualquer unidade retorna `409 Conflict`. A resposta
  mantém `id`, `operator_id`, `parking_id`, `starts_at` e `ends_at`; a mudança é
  registrada em `GET /partners/schedule-history`.
- `GET /partners/shifts` continua retornando todos os turnos futuros e passados
  da empresa para o gestor, inclusive turnos sem responsável (`operator_id: null`);
  para operador, limita aos próprios turnos.

## Operadores adicionais (parceiro e administrador)

- `POST /partners/operator-packages/requests`: cria solicitação de operadores adicionais (`quantity`, `package_type`=`individual|package`, `amount`). Inicia em `pending_payment`.
- `POST /partners/operator-packages/requests/{id}/receipt`: multipart com comprovante PDF/JPG/PNG (até 30 MB). Atualiza para `pending_review` e grava o arquivo no armazenamento local da VPS.
- `GET /partners/operator-packages/requests`: lista solicitações da empresa.
- `GET /admin/platform-fees/operator-packages/requests`: administrador lista solicitações de todas as empresas.
- `POST /admin/platform-fees/operator-packages/requests/{id}/approve` ou `/reject`: administrador revisa a solicitação. Solicitações aprovadas ampliam o limite de operadores da empresa.

Operadores só recebem dados dos estacionamentos em que possuem `operator_parking_assignments`; o mapa e as reservas operacionais aplicam esse filtro no backend.

### Horário de funcionamento e acesso à reserva

`GET /parkings` inclui `isOpen` e `operating_hours`. O app usa esses campos para informar quando a unidade está fechada e oferece agendamento para uma data futura. A API continua validando o horário no servidor durante a criação da pré-reserva.

### Reservas: nome da unidade e expiração

`GET /reservations` e `POST /reservations/pre-checkin` retornam `parking_name`
para que o cliente identifique a unidade sem uma chamada adicional. A listagem
também executa a expiração dos holds vencidos de forma idempotente: a reserva
fica `cancelled`, o pagamento `expired` e a vaga é devolvida à capacidade.

## Serviços extras da unidade

`ParkingManagementRequest.services` usa tipos previamente cadastrados (`car_wash`,
`insurance`, `transport` e `vip_spot`). O campo `name` é derivado pelo sistema;
o parceiro informa apenas `description` opcional. O valor `price` é enviado como
zero: o serviço extra não é cobrado individualmente do cliente. A taxa pela
ativação/uso de serviços adicionais é configurada pela gestão do app e aplicada
pela funcionalidade de serviços extras.

O retorno do dashboard inclui `additional_services`, separado de
`service_breakdown`: cada item contém `code`, `name`, `description`, quantidade
de reservas e receita associada.
# Customer assets — tipos de veículo

`POST /customer-assets/vehicles` aceita `vehicle_type` (`car`, `motorcycle` ou
`bicycle`) e `bicycle_parts` opcional. Para bicicleta, `plate` representa o
número de identificação e `vehicle_document` mantém o nome do comprovante PDF.
Clientes antigos que não enviam o campo continuam sendo tratados como `car`.
# Pagamento de reservas horárias

`POST /payments/reservations/{reservation_id}/intent` aceita `latitude` e
`longitude` opcionais. Para clientes pagando uma reserva horária ou excedente
de checkout, os dois campos são obrigatórios e a API exige distância máxima de
50 metros do estacionamento. Reservas diárias, semanais e mensais não usam
essa validação no pagamento do check-in.
# Conveniências da unidade de estacionamento

Gestores de uma unidade podem cadastrar produtos vendidos no local, separados
dos serviços extras da reserva:

- `GET /partners/parking-management/{parking_id}/conveniences`
- `POST /partners/parking-management/{parking_id}/conveniences`
- `PUT /partners/parking-management/{parking_id}/conveniences/{product_id}`
- `DELETE /partners/parking-management/{parking_id}/conveniences/{product_id}`

O payload usa `category`, `subcategory`, `name`, `description`, `price` e
`is_active`. A exclusão é lógica. O acesso é limitado ao tenant da unidade;
operadores podem consultar, mas somente gestor/admin pode alterar.
