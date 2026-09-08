# Roadmap

## Revisao de continuidade — 06/09/2026

Escopo desta rodada: servicos adicionais do estacionamento e gestao operacional do ParkHere.
O chat de autorizacao de eventos/secretarias pertence a outro produto e nao foi aplicado.
O roadmap abaixo e um backlog historico, nao uma lista de funcionalidades concluidas.

Verificado no codigo atual:
- Cadastro com quantidades de vagas VIP, carro grande, onibus e picape; mapa baseado na configuracao.
- Card de canceladas com quantidade/valor, cards financeiros de dimensoes iguais e tooltip no icone.
- Servicos adicionais, tarifas por area, reserva por vaga e chegada operacional manual.

Ajustado nesta rodada:
- Chegada selecionada no minuto atual permanece no mesmo dia.
- Servicos e tarifas rejeitam negativos/NaN/infinito; codigo de servico unico por estacionamento.
- Selecao repetida de um servico nao duplica sua cobranca; atualizacao retorna o catalogo salvo.
- Simulacao identificada como `mock` e `is_simulated`; confirmacao manual bloqueada para outros providers.
- Reservas encerradas/expiradas nao podem ser pagas pelo fluxo simulado; pagamento sem reserva removido do app.
- Cliente HTTP Mercado Pago para criar Pix com idempotencia e consultar pagamento, coberto por testes com transporte simulado.

Validacao desta rodada: 12 testes backend, 4 testes Flutter (3 de chegada e 1 smoke),
`flutter analyze` sem apontamentos e `git diff --check` limpo. Sem homologacao visual
ou cobranca real. O SDK local resolveu quatro dependencias do lockfile durante os
checks; as versoes que ja estavam no workspace foram restauradas ao final.

Proximos passos para pagamento real, em ordem:
1. OAuth do parceiro e armazenamento seguro/renovacao de credenciais.
2. Intent persistido antes da chamada externa, chave idempotente reutilizavel e recuperacao de timeout.
3. Webhook autenticado + consulta ao provedor, validacao de moeda/valor/referencia/recebedor e conciliacao idempotente.
4. Tela Pix pendente com QR real e consulta de status; cartao por tokenizacao do provedor.
5. Split marketplace 1:1, reembolso, ledger de creditos e homologacao ponta a ponta.

Nao habilitar `PAYMENT_PROVIDER=mercado_pago` para cobrancas ainda: o endpoint retorna 503 nesta fase.
Gestao ainda tem itens de roadmap abertos: fotos em storage seguro, politicas por parceiro,
incidentes e relatorios; os paineis de outros tipos de servico tambem nao estao concluidos.

## Fase 0: Organizacao

- Inicializar Git.
- Adicionar `.gitignore`.
- Criar documentacao local.
- Criar skills locais para agentes.
- Padronizar nome ParkHere.
- Remover arquivos gerados do versionamento antes do primeiro commit.

## Fase 1: MVP Operavel

- Corrigir autenticao/MFA do backend.
- Adicionar tela inicial com idioma PT-BR/EN e escolha Cliente/Parceiro.
- Criar tela de perfil com dados somente leitura, MFA por e-mail/telefone/app, troca de telefone validada por SMS e alteracao de senha forte.
- Criar modelos e endpoints de estacionamentos.
- Criar endpoints de precificacao e servicos adicionais.
- Criar fluxo backend de pre-reserva, reserva, expiracao e cancelamento.
- Pre-reserva deve expirar por `tempo de trajeto + tolerancia do parceiro`.
- Pre-reserva deve salvar/exibir estimativa de rota: minutos de trajeto e hora prevista de chegada para cliente e parceiro.
- Reserva confirmada por pagamento bloqueia a vaga sem limite de chegada alem do horario de funcionamento e regras do estabelecimento.
- Criar busca por cidade no mapa e priorizar estacionamentos proximos usando geolocalizacao autorizada.
- Criar fluxo de agendamento de reserva com data/hora futura, limite de antecedencia e politica de cancelamento por parceiro.
- Criar fluxo backend de check-in/checkout manual.
- Integrar app Flutter aos endpoints reais.
- Persistir pagamentos com status simulado ou sandbox.
- Preparar modulo de pagamentos com provider `mercado_pago`, Pix/cartao, split planejado e conta de repasse do parceiro.
- Testar calculo de preco e expiracao.
- Melhorar carteira do usuario com cartao salvo sem CVV e CVV solicitado apenas no pagamento.
- Criar historico de reservas com data, status, valor e tela de detalhes.
- Criar avaliacao simples de estacionamento/servico e app no detalhe da reserva.
- Criar navegacao responsiva: menu inferior simplificado no mobile e menu web por categorias.
- Regra de UX para todos os novos blocos: projetar primeiro para celulares, testar
  larguras de tablet e manter compatibilidade web. Seletores extensos devem usar
  listas/menus responsivos para evitar overflow e quebra de textos.
- Criar submenu de servicos com estacionamento, lava-jato, hoteis e passeios turisticos.
- Listar estacionamentos disponiveis dentro de Servicos > Estacionamento.
- Criar menu Reservas para reservas ativas e historico.
- Validar e-mail antes de liberar cadastro de cliente/parceiro.
- Criar recuperacao de senha por codigo enviado por e-mail e bloqueio do fluxo ate cadastrar nova senha.
- Criar checklist de publicacao Play Store/App Store e revisar permissao, privacidade e dados antes de builds de loja.
- Definir access token com validade de 6 horas, logout automatico em token expirado e em retorno `401 Unauthorized`.

## Fase 1.1: Cadastro De Parceiro Simples

- Criar tabela/API de categorias de parceiro: estacionamento, lava-jato, guia turistico, empresa de turismo, hotel, restaurante, transporte.
- Criar cadastro de parceiro com tipo de servico.
- Criar endpoint `/partners/me` para o app carregar a propria empresa e o tipo de painel autorizado.
- Criar status do parceiro: rascunho, aguardando documentos, aguardando vistoria, aprovado, reprovado, suspenso.
- Criar formulario simples no app/painel para dados do estabelecimento.
- Cadastro do estacionamento deve coletar portaria 24h, sistema de seguranca e interesse em atendimento automatico.
- Exigir aceite dos termos de responsabilidade no cadastro de cliente, parceiro e operador.
- Criar seed com parceiros de cada tipo.
- Testar listagem e aprovacao manual via API.
- Separar parceiros de divulgacao e parceiros de gestao.
- Separar interface `Minha empresa` do parceiro da futura gestao geral do admin do sistema.
- Separar papeis internos: `SUPER_ADMIN` para admin master ParkHere e `PARTNER_MANAGER` para gestor do estabelecimento.

## Fase 1.2: Documentos E Vistoria

- Criar cadastro de documentos obrigatorios por tipo de parceiro.
- Registrar documento pessoal do responsavel.
- Registrar alvara/documento do estabelecimento.
- Criar endpoint para atualizar status documental.
- Criar registro de vistoria com data, responsavel e resultado.
- Vistoria de estacionamento deve validar vagas, vagas cobertas, portaria, seguranca, acessos e documentos.
- Bloquear publicacao de parceiro sem aprovacao.

## Fase 1.3: Taxas E Divulgacao

- Criar tabela `platform_fees`.
- Permitir taxa por categoria de parceiro e por servico.
- Usar taxa hibrida configuravel no MVP: valor fixo minimo + percentual, com limite maximo opcional.
- Seed inicial de taxas: estacionamento, lava-jato, seguro, transporte e guia/turismo.
- Aplicar taxa no calculo de servico contratado.
- Salvar snapshot das taxas aplicadas na reserva para comprovante e auditoria.
- Criar cadastro basico de divulgacao para hoteis, restaurantes e turismo.
- Exibir divulgacoes simples no app apos reserva ou na tela de detalhes.
- Criar aba de propagandas com banners.
- Criar pagina interna de servico por parceiro.
- Permitir contratacao direta do servico pelo app.
- Aplicar taxa de servico do app na contratacao.

## Fase 1.4: Paineis Por Tipo De Parceiro

- Criar home `Minha empresa` que mostra apenas o painel permitido pelo `service_type` do parceiro.
- Ajustar navegacao do parceiro para nao exibir servicos publicos do cliente.
- Mapa do parceiro deve mostrar apenas vagas/operacao dos estacionamentos do proprio tenant.
- Reservas do parceiro devem listar apenas solicitacoes recebidas pelo proprio estabelecimento.
- Painel de estacionamento: tarifas hora/diaria/semanal/mensal, vagas, seguro, lavagem e operadores.
- Painel de lava-jato: servicos, agenda, execucao no estacionamento e status de lavagem.
- Painel de guia turistico: pacotes, agenda, idiomas e capacidade.
- Fluxo de guia/agente turistico com codigo de indicacao na reserva.
- Registrar comissao de guia por estabelecimento/servico no modulo financeiro Pro.
- Painel de empresa de turismo: passeios, horarios, vagas, politica de cancelamento e pacotes.
- Painel de hotel/restaurante: banners, pagina comercial e ofertas.
- Testar cada painel isoladamente antes de unir no fluxo completo.

## Fase 1.5: Gestao Do Admin Do Sistema

- Criar painel interno separado do painel do parceiro.
- Gerenciar parceiros, documentos, vistorias, status e suspensoes.
- Gerenciar taxas ParkHere por tipo de servico e plano.
- Gerenciar planos: free com gestao basica de vagas/taxas do parceiro e plano pago com financeiro/relatorios.
- Criar relatorio financeiro global da plataforma.
- Criar financeiro Pro do parceiro com repasses, taxas e comissoes de guias/agentes.
- Criar regra comercial de operadores: 2 inclusos no plano atual e taxa extra acima disso.
- Auditar reservas, pagamentos, repasses e comprovantes.
- Criar ledger de credito de carteira para cancelamentos, reembolsos parciais e uso em reservas futuras.
- Criar relatorio de credito aplicado na reserva para parceiro e admin.
- Garantir que parceiros nao visualizem dados de outros tenants.

## Fase 2: Operacao De Estacionamento

- Criar painel de gestao do estacionamento como primeiro painel de parceiro.
- Permitir cadastro de tarifas por hora, diaria, semanal e mensal.
- Permitir cadastro de subservicos do estacionamento, incluindo lava-jato, seguro e vagas especiais.
- Criar endpoints de gestao por parceiro para vagas cobertas/descobertas, tarifas por area e servicos extras.
- Criar tela Flutter de gestao do estacionamento consumindo `/partners/parking-management`.
- Recalcular reserva no backend usando tarifa cadastrada, area escolhida e servicos extras.
- Persistir snapshot financeiro da reserva: base, servicos, taxa da plataforma, total final e servicos contratados.
- Aplicar `platform_fees` no pre-check-in e explicitar taxa ParkHere no snapshot financeiro.
- Exibir taxas da plataforma no comprovante da reserva.
- Criar cadastro de conta de pagamento do parceiro para receber split/repasse.
- Criar intent de pagamento por reserva usando `final_total` calculado no backend.
- Confirmar pagamento e atualizar status da reserva.
- Painel ou app operacional para portaria.
- Criar mapa operacional 2D de vagas com status livre, pre-reservado e ocupado.
- Ao clicar em vaga ocupada/pre-reservada, mostrar detalhes da solicitacao.
- Mostrar reservas agendadas e previsao de chegada no mapa operacional do estacionamento.
- Ao clicar em vaga livre, operador pode criar reserva operacional e iniciar check-in pelo celular.
- Operador pode criar pre-reserva sem pagamento ou reserva confirmada com pagamento operacional.
- Pagamento operacional MVP: dinheiro com valor recebido/troco e Pix com QR code; cartao/maquininha fica para V2.
- Funcao caixa do estacionamento fica acoplada ao mapa de vagas no MVP: receber dinheiro/Pix, calcular troco, registrar pagamento e alimentar totais operacionais.
- Cards do mapa devem somar reservas, servicos, recebido e a receber por status.
- Check-in operacional deve exigir fotos de frente, traseira e laterais do veiculo.
- Proxima etapa: persistir fotos do check-in em storage seguro com auditoria por reserva.
- Gestao de vagas por setor/tipo.
- Evoluir mapa operacional para visualizacao 3D com veiculos e setores depois da modelagem de vagas fisicas.
- Gestao de servicos oferecidos pelo parceiro.
- Gestao de lava-jato executado no estacionamento.
- Historico de sessoes.
- Incidentes.
- Relatorios de ocupacao e receita.
- Permissoes por papel.
- Permissoes configuraveis por operador do parceiro.
- Operador do parceiro pertence ao tenant do parceiro que o criou.
- Operador do parceiro pode ver reservas, patio de vagas, criar reserva, cancelar reserva criada por ele, receber pagamento e fazer check-in/checkout manual das reservas criadas por ele, sem acesso a configuracoes financeiras.
- Reserva operacional criada no mapa deve gravar `spot_code`, tipo de vaga e previsao manual de chegada para nao deslocar a reserva para outra vaga.
- Mapa de vagas deve exibir tooltips nos indicadores financeiros e identificar vaga descoberta, coberta, VIP, carro grande, onibus e picape.
- Cancelamento MVP: gratuito ate 5 minutos; depois aplica taxa administrativa ParkHere cadastrada pelo gestor do app.
- Reserva com check-in so pode ser cancelada pelo gestor do parceiro; operador so cancela reservas proprias antes do check-in.
- Criar politicas de cancelamento por parceiro: prazo sem taxa, taxa fixa/percentual, tolerancia de atraso e no-show.
- Criar alertas de atraso para reserva pre-confirmada.
- Integrar confirmacao de reserva com pagamento Mercado Pago, Pix/cartao e split marketplace.
- Implementar Mercado Pago em blocos: client HTTP, OAuth do parceiro, payment intent, webhook, split 1:1, reembolso parcial/total, relatorios e conciliacao.
- Implementar carteira de credito antes de liberar cancelamento com credito em producao.
- Criar comprovante fiscal/operacional exibindo tarifa do parceiro, taxa ParkHere, taxa de cancelamento, credito aplicado e repasse.
- Criar aceite de termo de responsabilidade antes do check-in.

## Fase 3: Automacao

- Check-in por leitura de placa.
- Checkout por leitura de placa.
- Reconhecimento facial com consentimento explicito.
- Kit comercial V2 de reconhecimento facial + geolocalizacao + abertura/fechamento de portao para parceiros de estacionamento.
- Dispositivos/cameras integrados por eventos.
- Fallback manual obrigatorio.
- Auditoria de falsos positivos, LGPD e retencao de biometria.

## Fase 4: Escala

- Multiestacionamento por empresa: cada gestor pode cadastrar unidades com endereços distintos. A criação de uma nova unidade será liberada após pagamento da taxa de ativação; cada unidade inclui duas vagas de usuário por padrão.
- Associação e escala de operadores por unidade, com isolamento de dados no mapa, reservas, caixa e relatórios. Filtros universais permitirão selecionar todos ou uma unidade e indicar o operador do plantão.

- Multi-cidade.
- Ranking e recomendacao.
- Preco dinamico.
- Programa de fidelidade.
- Marketplace de servicos.
- Campanhas pagas de divulgacao para estabelecimentos.
- Observabilidade, SLAs e antifraude.
