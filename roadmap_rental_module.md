# Roadmap – Módulo de Locação de Veículos (ServiceHub)

## Visão geral
- **Objetivo:** adicionar ao sistema existente (ParkHere → ServiceHub) a funcionalidade de locação de veículos, permitindo que parceiros criem filiais do tipo "locação" e que motoristas reservem, paguem e finalizem a locação com check‑in/check‑out.
- **Integração:** reutiliza a mesma arquitetura de módulos já existente (backend FastAPI + frontend Flutter).  O fluxo segue o padrão do módulo de estacionamento, mas inclui etapas adicionais (empresa, lista de veículos, itens opcionais, fotos, contrato PDF, compartilhamento).

## Estrutura de código
### Backend (`parkhere_backend/app/modules/rentals`)
- `models/`
  - `rental_company.py` – tabela `rental_company`
  - `vehicle.py` – tabela `vehicle`
  - `rental_reservation.py` – tabela `rental_reservation`
  - `rental_checkin.py` – tabela `rental_checkin`
  - `rental_checkout.py` – tabela `rental_checkout`
- `schemas/`
  - `rental.py` – Pydantic schemas para request/response.
- `services/`
  - `rental_service.py` – lógica de cálculo, geração de PDF, associação de multas.
- `router.py` – endpoints REST:
  - `GET /rentals/companies`
  - `GET /rentals/companies/{id}/vehicles`
  - `POST /rentals/reservations`
  - `POST /rentals/checkin`
  - `POST /rentals/checkout`
  - `GET /rentals/fines/daily` (usado pelo cron).
- `cron/associate_fines.py` – rotina diária que associa multas a reservas.
- **Migração Alembic** (ex.: `xxxx_add_rental_module.py`).

### Frontend (`parkhere_user_app/lib/features/rental`)
- `models/`
  - `vehicle.dart`
- `pages/`
  - `company_selector_page.dart`
  - `vehicle_list_page.dart`
  - `reservation_page.dart`
  - `payment_page.dart`
  - `contract_page.dart`
  - `checkin_page.dart`
  - `checkout_page.dart`
- `providers/`
  - `rental_provider.dart` (state management via Riverpod).
- `services/`
  - `rental_service.dart` (wrapper para chamadas API).
- **Rotas** adicionadas ao `router.dart` (go_router) com caminho `/rental/*`.
- **Drawer** atualizado para gerar itens dinamicamente a partir de `partner.serviceModules`.

## Documentação
- `docs/api-contracts.md` – acrescentar descrição dos novos endpoints.
- `docs/features.md` – seção *Locação de Veículos*.
- `docs/architecture.md` – diagramas de módulos atualizados.
- `README.md` – passo a passo de teste manual.

## Cron / Agendamento
- Cron diário (`0 1 * * *`) que executa `associate_fines.py`.
- Configurado via a ferramenta `schedule` do Antigravity.

## Fluxo de UI (passos do usuário)
1. **Seleção da empresa** – mapa/lista de locadoras.
2. **Seleção do veículo** – lista filtrável.
3. **Reserva** – datas, km estimado, itens opcionais.
4. **Pagamento** – pix, dinheiro, cartão.
5. **Contrato** – PDF gerado, botão de compartilhamento.
6. **Check‑in** – captura de 4 fotos + seleção de itens.
7. **Check‑out** – foto final, registro de quilometragem, confirmação.

## Testes Manuais (checklist)
- [ ] Compilar Flutter (`flutter run -d web-server`).
- [ ] Navegar ao módulo via Drawer.
- [ ] Criar reserva completa e concluir pagamento.
- [ ] Ver PDF do contrato e compartilhar por e‑mail/WhatsApp.
- [ ] Realizar check‑in (foto + itens) e check‑out.
- [ ] Confirmar que as multas diárias são associadas via API.
- [ ] Verificar que o backend persiste corretamente nas tabelas.

---
*Este roadmap será mantido como artefato permanente e pode ser consultado a qualquer momento.*
