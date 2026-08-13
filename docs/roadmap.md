# Roadmap

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
- Criar fluxo backend de check-in/checkout manual.
- Integrar app Flutter aos endpoints reais.
- Persistir pagamentos com status simulado ou sandbox.
- Testar calculo de preco e expiracao.
- Melhorar carteira do usuario com cartao salvo sem CVV e CVV solicitado apenas no pagamento.
- Criar historico de reservas com data, status, valor e tela de detalhes.
- Criar avaliacao simples de estacionamento/servico e app no detalhe da reserva.
- Criar navegacao responsiva: menu inferior simplificado no mobile e menu web por categorias.
- Criar submenu de servicos com estacionamento, lava-jato, hoteis e passeios turisticos.
- Listar estacionamentos disponiveis dentro de Servicos > Estacionamento.
- Criar menu Reservas para reservas ativas e historico.
- Validar e-mail antes de liberar cadastro de cliente/parceiro.
- Criar recuperacao de senha por codigo enviado por e-mail e bloqueio do fluxo ate cadastrar nova senha.
- Criar checklist de publicacao Play Store/App Store e revisar permissao, privacidade e dados antes de builds de loja.

## Fase 1.1: Cadastro De Parceiro Simples

- Criar tabela/API de categorias de parceiro: estacionamento, lava-jato, guia turistico, empresa de turismo, hotel, restaurante, transporte.
- Criar cadastro de parceiro com tipo de servico.
- Criar status do parceiro: rascunho, aguardando documentos, aguardando vistoria, aprovado, reprovado, suspenso.
- Criar formulario simples no app/painel para dados do estabelecimento.
- Criar seed com parceiros de cada tipo.
- Testar listagem e aprovacao manual via API.
- Separar parceiros de divulgacao e parceiros de gestao.

## Fase 1.2: Documentos E Vistoria

- Criar cadastro de documentos obrigatorios por tipo de parceiro.
- Registrar documento pessoal do responsavel.
- Registrar alvara/documento do estabelecimento.
- Criar endpoint para atualizar status documental.
- Criar registro de vistoria com data, responsavel e resultado.
- Bloquear publicacao de parceiro sem aprovacao.

## Fase 1.3: Taxas E Divulgacao

- Criar tabela `platform_fees`.
- Permitir taxa por categoria de parceiro e por servico.
- Aplicar taxa no calculo de servico contratado.
- Criar cadastro basico de divulgacao para hoteis, restaurantes e turismo.
- Exibir divulgacoes simples no app apos reserva ou na tela de detalhes.
- Criar aba de propagandas com banners.
- Criar pagina interna de servico por parceiro.
- Permitir contratacao direta do servico pelo app.
- Aplicar taxa de servico do app na contratacao.

## Fase 1.4: Paineis Por Tipo De Parceiro

- Painel de estacionamento: tarifas hora/diaria/semanal/mensal, vagas, seguro, lavagem e operadores.
- Painel de lava-jato: servicos, agenda, execucao no estacionamento e status de lavagem.
- Painel de guia turistico: pacotes, agenda, idiomas e capacidade.
- Painel de empresa de turismo: passeios, horarios, vagas, politica de cancelamento e pacotes.
- Painel de hotel/restaurante: banners, pagina comercial e ofertas.
- Testar cada painel isoladamente antes de unir no fluxo completo.

## Fase 2: Operacao De Estacionamento

- Criar painel de gestao do estacionamento como primeiro painel de parceiro.
- Permitir cadastro de tarifas por hora, diaria, semanal e mensal.
- Permitir cadastro de subservicos do estacionamento, incluindo lava-jato, seguro e vagas especiais.
- Exibir taxas da plataforma no comprovante da reserva.
- Painel ou app operacional para portaria.
- Gestao de vagas por setor/tipo.
- Gestao de servicos oferecidos pelo parceiro.
- Gestao de lava-jato executado no estacionamento.
- Historico de sessoes.
- Incidentes.
- Relatorios de ocupacao e receita.
- Permissoes por papel.

## Fase 3: Automacao

- Check-in por leitura de placa.
- Checkout por leitura de placa.
- Reconhecimento facial com consentimento explicito.
- Dispositivos/cameras integrados por eventos.
- Fallback manual obrigatorio.
- Auditoria de falsos positivos, LGPD e retencao de biometria.

## Fase 4: Escala

- Multi-cidade.
- Ranking e recomendacao.
- Preco dinamico.
- Programa de fidelidade.
- Marketplace de servicos.
- Campanhas pagas de divulgacao para estabelecimentos.
- Observabilidade, SLAs e antifraude.
