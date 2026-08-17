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
        "arrival_estimate_at": "2026-08-17T10:36:00",
        "is_manual_arrival": false
      }
    }
  ],
  "cards": "deprecated; usar campos agregados de valor e quantidade no nivel do estacionamento"
}
```

Regras:

- Parceiro e operador veem apenas reservas do proprio estabelecimento/tenant.
- O card da vaga deve mostrar a previsao em formato curto, por exemplo `14 min · 10h36`.
- Reserva operacional deve permanecer vinculada ao `spot_code` selecionado no mapa de vagas.
- Reserva cancelada entra nos indicadores de cancelamento, mas nao bloqueia vaga no mapa.
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
- Para reserva criada por operador/parceiro, `arrival_estimate_at` pode ser manual e `is_manual_arrival=true`.
- Expiracao da pre-reserva usa `route_minutes + tolerancia do parceiro`.
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

Regras:

- Cliente pode cancelar a propria pre-reserva/reserva.
- Operador pode cancelar somente pre-reserva ou reserva criada por ele enquanto nao houve check-in.
- Reserva com check-in so pode ser cancelada pelo gestor do parceiro.
- Cancelamento ate 5 minutos apos criacao nao cobra taxa.
- Apos 5 minutos, aplica taxa administrativa ParkHere configurada como `platform_fee.service_type=cancellation`.
- Taxa de cancelamento do parceiro por estacionamento entra no proximo bloco de politica operacional.
