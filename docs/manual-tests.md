# Testes Manuais MVP

Use este roteiro depois de subir o Docker pela raiz do projeto.

```bash
docker compose up --build
```

URLs:

- App web: http://localhost:8080
- API: http://localhost:8000
- MySQL host: `localhost:3307`

Contas seed:

- Cliente: `cliente@parkhere.test` / `123456`
- Parceiro/admin estacionamento: `admin@parkhere.test` / `123456`
- Parceiro dono/gestor: `parceiro@parkhere.test` / `123456`
- Operador do parceiro: `operador@parkhere.test` / `123456`
- MFA local: `000000`

## Fluxo Cliente: Reserva, Check-in, Pagamento E Checkout

1. Acesse http://localhost:8080.
2. Escolha entrar como `Cliente`.
3. Faça login com `cliente@parkhere.test` / `123456`.
4. Digite MFA `000000`.
5. Abra `Serviços > Estacionamento` ou use o mapa.
6. Selecione um estacionamento disponível.
7. Escolha plano e serviços extras.
8. Confirme a rota/pre-reserva.
9. Na tela de rota, escolha `Check-in antecipado e pagamento`.
10. Marque/capture as 4 fotos obrigatórias.
11. Confirme pagamento.
12. O app deve chamar o backend de pagamento quando a reserva tiver `reservationId`.
13. O backend cria `payment_transactions` com provider `mercado_pago`, split ParkHere/parceiro e status `paid` após confirmação mock.
14. A reserva local deve aparecer no histórico.
15. Acesse `Menu > Reservas`.
16. Abra a reserva e realize checkout quando a tela permitir.

## Fluxo Parceiro: Gestão Do Estacionamento

1. Faça logout.
2. Entre como `Parceiro`.
3. Login: `admin@parkhere.test` / `123456`.
4. MFA: `000000`.
5. A tela inicial deve abrir em `Minha empresa`.
6. Confira vagas cobertas/descobertas, tarifas, portaria, segurança e serviços extras.
7. Crie ou edite um estacionamento.
8. Abra `Mapa de vagas` e confirme que só aparece o estabelecimento do tenant logado.
9. Abra `Reservas recebidas` e confirme que só aparecem reservas do estabelecimento.
10. Abra `Usuarios` e confirme que `operador@parkhere.test` aparece.
11. Tente criar operador sem aceitar termos e confirme bloqueio.
12. Verifique se aparece em `GET /partners/parking-management`.

## Fluxo Parceiro: Operador

1. Faça logout.
2. Entre como `Parceiro`.
3. Login: `operador@parkhere.test` / `123456`.
4. MFA: `000000`.
5. Confirme acesso a `Mapa de vagas` e `Reservas recebidas`.
6. Confirme que gestão administrativa de estacionamento retorna `403` na API.

## Validações De API

Criar reserva com taxa ParkHere:

```bash
PARKING_ID=$(docker compose exec -T mysql mysql -N -uroot -proot parkfinder -e "SELECT id FROM parkings WHERE name='Estacionamento Central ParkHere' LIMIT 1" 2>/dev/null | tr -d '\r')

curl -X POST http://localhost:8000/reservations/pre-checkin \
  -H 'Content-Type: application/json' \
  -d "{\"parking_id\":\"$PARKING_ID\",\"route_minutes\":15,\"spot_type\":\"covered\",\"pricing_plan\":\"daily\",\"duration_hours\":1,\"service_codes\":[\"car_wash\"]}"
```

Criar intenção de pagamento:

```bash
curl -X POST http://localhost:8000/payments/reservations/{reservation_id}/intent \
  -H 'Content-Type: application/json' \
  -d '{"method":"pix"}'
```

Confirmar pagamento mock:

```bash
curl -X POST http://localhost:8000/payments/{payment_id}/confirm
```

Resultado esperado:

- `gross_amount`: total pago pelo usuário.
- `platform_fee_amount`: taxa ParkHere.
- `partner_amount`: repasse do parceiro.
- `split`: linhas ParkHere/parceiro.
- `payment_status` da reserva: `paid` após confirmação.
