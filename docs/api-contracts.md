# Contratos De API

Este arquivo registra os payloads que o app Flutter espera do backend. Sempre que endpoint, schema ou campo mudar, atualizar aqui junto com o codigo.

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

Request:

```json
{
  "name": "Estacionamento Central ParkHere",
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
  "service_codes": ["car_wash"]
}
```

Response:

```json
{
  "reservation_id": "reservation-id",
  "walk_in_plate": null,
  "walk_in_phone": null,
  "status": "pre_reserved",
  "payment_status": "pending",
  "spot_code": "V003",
  "route_minutes": 14,
  "expires_at": "2026-08-17T10:46:00",
  "arrival_estimate_at": "2026-08-17T10:36:00",
  "is_manual_arrival": false,
  "base_amount": 12.0,
  "services_amount": 35.0,
  "platform_fee_amount": 3.0,
  "final_total": 50.0
}
```

Regras:

- Backend recalcula valores e nao confia em total enviado pelo app.
- Cliente deve informar `vehicle_id`; parceiro/operador deve informar `walk_in_plate` e `walk_in_phone`.
- Para reserva criada por operador/parceiro, `arrival_now=true` grava o horario atual no servidor; se for agendada, `arrival_estimate_at` deve vir com timezone ou sera tratado como horario local de `America/Bahia`.
- Expiracao da pre-reserva usa `arrival_estimate_at + arrival_tolerance_minutes`.
- Ao nao informar `spot_code`, o backend escolhe uma vaga livre compativel com `spot_type`.
- Duas reservas simultaneas para a mesma vaga geram uma confirmacao e uma falha `409`.
- Reserva agendada futura deve validar horario de funcionamento, antecedencia maxima e politica de cancelamento antes da confirmacao.
- Politica de cancelamento deve explicitar prazo sem taxa, taxa do estacionamento, taxa ParkHere e regra de credito em carteira.

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

## Pagamento De Reserva E Excedente

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

Regras:

- Cliente pode cancelar a propria pre-reserva/reserva.
- Operador pode cancelar somente pre-reserva ou reserva criada por ele enquanto nao houve check-in.
- Reserva com check-in so pode ser cancelada pelo gestor do parceiro.
- Cancelamento ate 5 minutos apos criacao nao cobra taxa.
- Apos 5 minutos, aplica taxa administrativa ParkHere configurada como `platform_fee.service_type=cancellation`.
- Taxa de cancelamento do parceiro por estacionamento entra no proximo bloco de politica operacional.


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
