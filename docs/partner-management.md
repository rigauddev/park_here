# Gestao De Parceiros E Estabelecimentos

## Status Atual

Hoje a gestao existe em dois blocos diferentes:

- `tenants` representam estabelecimentos/contas parceiras.
- `PARTNER_MANAGER` representa dono/gestor de um estabelecimento parceiro.
- `PARKING_ADMIN` fica como papel legado temporario para dados antigos e deve ser migrado para `PARTNER_MANAGER`.
- `SUPER_ADMIN` representa a gestao interna ParkHere/Rigaud Tech.
- `/auth/register-parking` cadastra um estacionamento inicial.
- `parkings` e `parking_services` ja existem para alimentar o app do motorista.
- `/partners/me` identifica a empresa do parceiro logado e informa o tipo de painel que o app deve abrir.
- `/partners/parking-management` permite que o parceiro de estacionamento administre apenas estacionamentos e servicos do proprio `tenant_id`.

O painel completo do admin do sistema ainda deve ser separado do painel do parceiro.

## Entrada No Sistema

A pagina inicial deve ter:

- Seletor de idioma: Portugues Brasil e Ingles.
- Entrada como cliente.
- Entrada como parceiro.

## Papeis Administrativos

O sistema nao deve usar um unico admin operacional com acesso amplo para todas as rotinas do dia a dia. A recomendacao e separar os acessos:

- `SUPER_ADMIN`: acesso interno ParkHere/Rigaud Tech para configuracao global, auditoria, taxas da plataforma, publicacao/suspensao de parceiros e suporte critico.
- `USER_ADMIN`: gestao de usuarios, suporte ao cliente, verificacao de cadastros e bloqueios operacionais, sem acesso livre a configuracoes financeiras globais.
- `PARTNER_ADMIN`: dono ou gestor do estabelecimento parceiro, com acesso apenas ao proprio tenant/estabelecimento.
- `OPERATOR`: colaborador do parceiro para check-in, checkout, reservas e execucao de servicos.

O login pode usar o mesmo endpoint tecnico, mas backend e app devem validar `account_type` e `role`. Cliente tentando entrar na area de parceiro, ou parceiro tentando entrar na area de cliente, deve receber erro generico de credenciais invalidas.

## Separacao Entre Gestao Do Parceiro E Gestao Do Sistema

Gestao do parceiro:

- Acesso pela area `Minha empresa`.
- Sempre isolada pelo `tenant_id` do usuario logado.
- Parceiro visualiza apenas a propria empresa.
- Menu do parceiro nao exibe servicos publicos do app do cliente.
- Mapa do parceiro exibe operacao/vagas do proprio estacionamento, nao busca publica de estacionamentos.
- Reservas do parceiro exibem apenas solicitacoes feitas para estacionamentos do proprio tenant.
- Parceiro cadastra e edita apenas servicos relacionados ao tipo escolhido no cadastro.
- Parceiro nao acessa taxas globais, dados de outros parceiros, aprovacao geral, vistoria global ou relatorios financeiros de plataforma.
- Parceiro pode ter operadores com permissao simplificada para reservar vaga, receber pagamento, fazer check-in e checkout manual.
- Parceiro dono/gestor pode criar ate 2 operadores no plano atual; acima disso exige taxa adicional ou upgrade de plano.
- Criacao de operador exige aceite dos termos de responsabilidade.

Gestao do admin do sistema:

- Acesso restrito a `SUPER_ADMIN` e papeis internos definidos.
- Aprova ou suspende parceiros.
- Gerencia documentos, vistorias, categorias de parceiro e planos.
- Cadastra taxas ParkHere por tipo de servico.
- Acompanha relatorios financeiros globais da plataforma.
- Audita reservas, pagamentos, repasses e suporte critico.
- Realiza vistoria presencial do local antes de aprovar/publicar o parceiro no app.

## Tipos De Parceiro

- Estacionamento.
- Lava-jato.
- Guia turistico.
- Empresa de turismo.
- Hotel.
- Restaurante.
- Transporte.
- Outro servico local aprovado.

## Parceiros De Divulgacao E Parceiros De Gestao

Existem dois grupos:

- Parceiros de divulgacao: hoteis, restaurantes e estabelecimentos locais que exibem banners/ofertas e redirecionam para uma pagina de servico dentro do app.
- Parceiros de gestao: estacionamentos, lava-jatos, guias e empresas de turismo que precisam cadastrar agenda, precos, taxas, execucao operacional e servicos contrataveis no app.

## Painel Por Tipo De Parceiro

Cada parceiro deve ver um painel de gestao conforme o tipo selecionado:

- Estacionamento: vagas, tarifas por hora/diaria/semanal/mensal, check-in, checkout, servicos adicionais, seguro e operadores.
- Lava-jato: servicos de lavagem, precos, disponibilidade, execucao no local do estacionamento e confirmacao de servico.
- Guia turistico: pacotes, agenda, pontos de encontro, idiomas, limite de pessoas e taxa por pacote.
- Empresa de turismo: passeios, pacotes, horarios, capacidade, politicas de cancelamento e divulgacao.
- Hotel/restaurante: banners, pagina promocional, links/redes sociais e ofertas contrataveis quando habilitadas.

Regra de produto: o parceiro nao troca livremente para outro painel. O painel e definido pelo `service_type` cadastrado e aprovado. Para operar mais de um tipo de servico, o parceiro deve solicitar nova habilitacao ou ter o tipo adicional aprovado pela gestao ParkHere.

## Guias Turisticos E Indicacoes

Fluxo a amadurecer:

- Guia turistico pode se cadastrar como parceiro ou agente indicado por um estabelecimento.
- Guia recebe um codigo unico de indicacao.
- Usuario pode selecionar um guia na reserva ou informar o codigo do guia.
- Indicacao fica registrada na reserva para auditoria e comissionamento.
- Guia pode indicar estacionamento, lava-jato, passeios, hoteis e outros servicos.
- Comissao do guia deve ser negociada/configurada entre guia e parceiro ou por regra do plano.
- Modulo financeiro Pro deve calcular comissoes por periodo, estabelecimento, guia e servico.

No MVP, o codigo de guia e o vinculo da reserva podem entrar antes do pagamento real de comissao. O repasse automatico fica para um bloco posterior junto com financeiro.

## Gestao De Estacionamento MVP

Primeiro bloco implementavel da fase de gestao:

- Parceiro com papel `PARTNER_MANAGER` entra na area de gestao do proprio estabelecimento.
- Parceiro lista apenas estacionamentos do proprio `tenant_id`.
- Parceiro cadastra/edita nome, endereco, latitude, longitude e status ativo.
- Parceiro informa se possui portaria 24h.
- Parceiro informa se possui sistema de seguranca.
- Parceiro informa se pretende usar atendimento automatico.
- Atendimento automatico com reconhecimento facial exige cadastro especifico, consentimento, vistoria tecnica e fica no roadmap V2.
- Parceiro informa quantidade total de vagas.
- Parceiro separa vagas cobertas e descobertas.
- Soma de vagas cobertas e descobertas deve ser igual ao total.
- Parceiro define a quantidade de vagas especiais: VIP, carro grande, onibus e picape.
- A soma das vagas especiais nao pode ser maior que a quantidade total de vagas.
- O mapa de vagas deve classificar as vagas a partir dessa configuracao do estacionamento.
- Vagas disponiveis nao podem ser negativas nem maiores que o total.
- Parceiro cadastra tarifas para area descoberta: primeira hora, hora adicional, diaria, semanal e mensal.
- Parceiro cadastra tarifas para area coberta: primeira hora, hora adicional, diaria, semanal e mensal.
- Parceiro cadastra servicos extras com codigo, nome, preco e status ativo.
- Exemplos de servicos extras: lava-jato, seguro avulso, transporte, vaga VIP.
- O app do cliente continua consumindo `/parkings`; os dados cadastrados na gestao alimentam busca/reserva.
- Reserva/pre-check-in recalcula o preco no backend usando plano, tipo da vaga e servicos extras.
- Check-in e checkout continuam usando o fluxo atual. Proximos blocos devem aplicar pagamento/check-in sobre o snapshot financeiro da reserva.

### Endpoints

- `GET /partners/me`
- `GET /partners/parking-map`
- `GET /partners/reservations`
- `GET /partners/operators`
- `POST /partners/operators`
- `GET /partners/parking-management`
- `POST /partners/parking-management`
- `GET /partners/parking-management/{parking_id}`
- `PUT /partners/parking-management/{parking_id}`

Todos exigem bearer token de parceiro/admin e isolamento por `tenant_id`. No MVP, `SUPER_ADMIN` pode usar endpoints tecnicos para suporte, mas a interface de admin do sistema deve ficar separada da interface do parceiro.

`GET /partners/operators` pode ser usado por gestor e operador do tenant para listar equipe. `POST /partners/operators` exige `PARTNER_MANAGER`, aceite de termos, respeita o limite gratuito de 2 operadores e cria o operador sempre no mesmo `tenant_id` do parceiro gestor.

## Permissoes Do Parceiro

Dono/gestor (`PARTNER_MANAGER`):

- Gerencia dados do estacionamento.
- Gerencia tarifas e servicos.
- Cria operadores.
- Acessa mapa de vagas e reservas recebidas.
- Pode fazer check-in/checkout manual nas reservas do proprio estabelecimento.

Operador (`OPERATOR`):

- Pertence ao estabelecimento do parceiro que o criou.
- Acessa somente as telas operacionais liberadas por permissao.
- Permissoes padrao: ver reservas, ver patio de vagas, criar reserva operacional, cancelar reserva criada por ele, receber pagamento, fazer check-in e checkout das reservas criadas por ele.
- Operador so pode cancelar reserva/pre-reserva propria antes do check-in; reserva com check-in exige gestor do parceiro.
- Pode receber pagamento e fazer check-in/checkout manual quando o fluxo operacional permitir.
- Funcao caixa operacional permite receber dinheiro/Pix no mapa de vagas ou nos detalhes da reserva.
- Modalidade por hora deve ficar para pagamento no checkout, pois o valor final depende do tempo real de permanencia.
- Diaria/semanal/mensal podem permitir pagar agora ou pagar na volta conforme decisao operacional do estabelecimento.
- Nao altera tarifas, dados cadastrais, financeiro, taxas ou usuarios.
- Nao deve ver menu de cliente, veiculos, carteira ou servicos publicos.

Permissoes MVP:

- `reservations.view`: ver reservas recebidas.
- `parking_map.view`: ver patio de vagas.
- `reservations.create`: criar reserva operacional.
- `reservations.cancel_own`: cancelar reservas criadas pelo proprio operador.
- `checkin.own`: realizar check-in de reservas criadas pelo proprio operador.
- `checkout.own`: realizar checkout de reservas criadas pelo proprio operador.
- `payments.receive`: receber pagamento no local.

Cliente:

- Quando a reserva pertence ao cliente no app, o check-in e checkout principal devem ser feitos pelo proprio cliente.
- Estabelecimento pode atuar como apoio/manual fallback quando necessario e auditavel.

## Mapa Operacional De Vagas

MVP:

- Exibir uma grade interativa 2D com vagas livres, pre-reservadas e ocupadas.
- Ao tocar em uma vaga com reserva, mostrar status, pagamento, placa, veiculo e valor.
- Ao tocar em uma vaga livre, abrir criacao de pre-reserva ou reserva operacional vinculada ao codigo da vaga.
- Vagas devem mostrar tipo: descoberta, coberta, VIP, carro grande, onibus ou picape, conforme configuracao cadastrada pelo parceiro.
- Reserva criada por operador/parceiro usa previsao manual de chegada informada no atendimento.
- Cards financeiros do mapa devem ter tooltip explicando o indicador, aberto apenas pelo icone de informacao.
- Mapa deve exibir indicador de reservas canceladas com quantidade e valor, sem ocupar vagas.
- Gerar o mapa com base em reservas e capacidade do estacionamento enquanto ainda nao existe modelagem de vaga individual.

Roadmap:

- Criar cadastro real de vagas/setores/andares.
- Evoluir para visualizacao 3D do estacionamento com veiculos e zonas.
- Associar cada reserva/check-in a uma vaga fisica.

## Aprovacao, Vistoria E Publicacao

- Cadastro do parceiro nasce como `waiting_documents` ou `waiting_inspection`.
- Estabelecimento so aparece para clientes quando estiver aprovado e ativo.
- Campo "ativo no app" indica publicacao operacional, mas nao substitui aprovacao/vistoria da gestao ParkHere.
- Equipe interna valida documentos, alvara, responsavel, fotos e vistoria presencial.
- Para estacionamento, vistoria deve registrar quantidade de vagas, vagas cobertas, acessos, portaria 24h, seguranca e capacidade de atendimento.

## Kit Reconhecimento Facial V2

- Criar oferta/kit de venda para estacionamentos que desejam automacao de check-in/checkout.
- Kit pode incluir reconhecimento facial, geolocalizacao, integracao com abertura/fechamento de portao e fallback manual.
- Exige consentimento explicito do usuario, politica LGPD, auditoria, retencao limitada e alternativa sem biometria.
- V2 deve suportar validacao por reconhecimento facial + geolocalizacao antes de acionar portao.

## Calculo De Reserva MVP

Endpoint:

- `POST /reservations/pre-checkin`

Payload adicional aceito:

- `spot_type`: `uncovered` ou `covered`.
- `pricing_plan`: `hourly`, `daily`, `weekly` ou `monthly`.
- `duration_hours`: duracao usada para plano por hora.
- `service_codes`: lista de servicos extras ativos do estacionamento.

Regras:

- Backend ignora qualquer total enviado pelo app e recalcula o valor.
- Plano por hora usa primeira hora + horas adicionais.
- Plano diario/semanal/mensal usa a tarifa cadastrada para a area escolhida.
- Servicos extras sao validados contra `parking_services` ativos.
- Reserva salva `base_amount`, `services_amount`, `platform_fee_amount`, `final_total` e snapshot dos servicos.
- Reserva salva tambem o snapshot das taxas ParkHere aplicadas por tipo de servico.
- `platform_fee_amount` e calculado via `platform_fees`, nao hard-coded no app.
- Disponibilidade ainda e global por estacionamento no MVP; controle por area coberta/descoberta fica para o proximo bloco operacional.

## Taxa De Servico ParkHere

Decisao MVP: usar taxa hibrida configuravel por tipo de servico.

Formula:

```text
taxa = valor_fixo + percentual_do_servico
```

Com suporte a:

- `fee_mode`: `fixed`, `percentage` ou `hybrid`.
- `fixed_amount`: valor fixo.
- `percentage`: percentual aplicado sobre o valor do servico.
- `min_fee`: taxa minima.
- `max_fee`: teto opcional.

Seed inicial:

- `parking`: R$ 1,50 + 5%, maximo R$ 15.
- `car_wash`: R$ 2,00 + 8%, maximo R$ 12.
- `insurance`: 10%.
- `transport`: R$ 2,50 + 7%, maximo R$ 15.
- `tour_guide`: 10%.

Taxa progressiva por faixa fica para uma fase futura, depois de observar ticket medio, custo de pagamento, suporte e conversao.

## Pagamento E Split MVP

Decisao: o usuario faz um pagamento unico e o backend prepara o split.

Fluxo:

1. Reserva calcula `final_total` no backend.
2. App solicita `POST /payments/reservations/{reservation_id}/intent`.
3. Backend cria uma transacao com provider `mercado_pago`.
4. Split planejado separa:
   - taxa ParkHere para `parkhere_app`.
   - valor do parceiro para a conta Mercado Pago cadastrada no tenant.
5. Confirmacao atualiza `payment_transactions.status` e `reservations.payment_status`.

MVP atual:

- `mercado_pago` fica em modo mock/sandbox ate configurar credenciais reais.
- Seed cria uma conta parceira fake `mp_seller_parkhere_seed`.
- Pix retorna um `qr_code` mock para validar fluxo.
- O app ja envia pagamento usando `reservationId` quando a reserva veio da API.

Variaveis previstas:

- `PAYMENT_PROVIDER=mercado_pago`
- `MERCADO_PAGO_ACCESS_TOKEN`
- `MERCADO_PAGO_PUBLIC_KEY`
- `MERCADO_PAGO_WEBHOOK_SECRET`

### Payload De Cadastro

```json
{
  "name": "ParkHere Centro",
  "address": "Rua Conselheiro Ferraz, Centro, Valenca - BA",
  "city": "Valenca",
  "lat": -13.3703,
  "lng": -39.0731,
  "total_spots": 60,
  "covered_spots": 24,
  "uncovered_spots": 36,
  "available_spots": 60,
  "has_vip_spots": true,
  "has_24h_gate": true,
  "has_security_system": true,
  "wants_automatic_access": true,
  "has_automatic_access": false,
  "uncovered_pricing": {
    "first_hour_price": 10,
    "additional_hour_price": 5,
    "daily_price": 40,
    "weekly_price": 180,
    "monthly_price": 300
  },
  "covered_pricing": {
    "first_hour_price": 14,
    "additional_hour_price": 7,
    "daily_price": 52,
    "weekly_price": 230,
    "monthly_price": 380
  },
  "services": [
    {
      "code": "car_wash",
      "name": "Lava-jato",
      "price": 35,
      "is_active": true
    },
    {
      "code": "insurance",
      "name": "Seguro avulso",
      "price": 8,
      "is_active": true
    }
  ],
  "is_active": true
}
```

## Cadastro De Parceiro

Campos minimos:

- Tipo de servico.
- Nome comercial.
- Documento fiscal: CNPJ ou CPF.
- Responsavel legal.
- Documento pessoal do responsavel.
- Endereco.
- Contatos.
- Alvara/documento operacional quando aplicavel.
- Fotos ou comprovacoes do local.

## Vistoria E Aprovacao

Status recomendado:

- `draft`
- `waiting_documents`
- `waiting_inspection`
- `approved`
- `rejected`
- `suspended`

Regra: parceiro so aparece no app depois de aprovado.

## Lava-Jato

O lava-jato pode se cadastrar como parceiro, mas servicos comprados dentro do fluxo de estacionamento devem ser executados no local do estacionamento. No futuro, o sistema pode permitir agenda, fila operacional e confirmacao de execucao.

## Taxas

A plataforma deve permitir cadastro de taxas por:

- Tipo de parceiro.
- Categoria de servico.
- Servico especifico.
- Plano do parceiro.

Taxas nao devem ficar hard-coded no app. O backend deve ser fonte de verdade.

Para estacionamentos, o parceiro deve cadastrar valores por:

- Hora.
- Diaria.
- Semanal.
- Mensal.
- Servicos extras, como seguro, lavagem, transporte ou vagas especiais.

## Aba De Propagandas

O app deve ter uma aba de propagandas/ofertas com banners por estabelecimento.

Fluxo:

1. Parceiro cadastra banner e pagina de servico.
2. Usuario visualiza banners no app.
3. Ao tocar no banner, abre uma pagina do servico dentro do app.
4. Usuario pode contratar o servico pelo app quando o parceiro habilitar venda direta.
5. Backend aplica a taxa de servico configurada pela gestao ParkHere.

## Entregas Pequenas

1. Criar categorias de parceiro e seed.
2. Criar cadastro simples de parceiro.
3. Criar documentos obrigatorios.
4. Criar vistoria manual.
5. Criar cadastro de taxas.
6. Aplicar taxa em servicos adicionais.
7. Criar divulgacao simples de hoteis/restaurantes/turismo.
8. Criar paginas internas de servico por parceiro.
9. Habilitar contratacao direta com taxa do app.
