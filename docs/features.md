# Funcionalidades

## Motorista

- Escolher idioma na pagina inicial: Portugues Brasil ou Ingles.
- Entrar como cliente.
- Criar conta e autenticar.
- Visualizar estacionamentos no mapa.
- Filtrar por vagas, cobertura, vagas VIP e servicos.
- Ver preco por hora, diaria e mensal.
- Fazer pre-reserva enquanto se desloca ate o estacionamento.
- Escolher plano e servicos adicionais.
- Pagar reserva.
- Fazer check-in ao chegar.
- Fazer checkout e receber valor final.
- Reportar incidente em uma reserva.

## Estacionamento

- Entrar como parceiro.
- Cadastrar estacionamento como tenant.
- Enviar documentacao do estabelecimento, alvara e documentos pessoais do responsavel.
- Aguardar vistoria/aprovacao antes de publicar.
- Gerenciar usuarios internos: admin, operador, guia/servico.
- Configurar precificacao.
- Configurar servicos adicionais.
- Cadastrar taxas repassadas pela plataforma por tipo de servico.
- Controlar vagas disponiveis.
- Validar check-in e checkout manualmente na portaria.
- Consultar reservas ativas, expiradas, canceladas e finalizadas.

## Admin Plataforma

- Consultar tenants.
- Gerenciar planos.
- Gerenciar tipos de parceiro e categorias de servico.
- Cadastrar taxas por servico, categoria e parceiro.
- Aprovar ou reprovar documentacao.
- Registrar vistoria do estabelecimento.
- Acompanhar metricas de reservas, ocupacao e receita.
- Auditar incidentes e pagamentos.

## Servicos Adicionais

Servicos iniciais:

- Lava-jato.
- Guia turistico.
- Transporte.
- Vaga coberta como atributo/filtro.
- Vaga VIP como atributo/filtro.

Regras:

- Servico adicional deve pertencer a um estacionamento.
- Lava-jato parceiro pode se cadastrar na plataforma, mas a lavagem contratada pelo app deve ser executada no local do estacionamento.
- Hoteis, restaurantes e turismo entram como divulgacao/ofertas locais, nao bloqueiam vaga.
- Servico pode ter preco fixo ou regra propria futura.
- Servico contratado deve ser registrado na reserva para faturamento e operacao.
- Taxa da plataforma deve ser calculada por configuracao administrativa, nao hard-coded no app.

## Gestao De Parceiros

Funcionalidades de parceiro:

- Cadastro escolhendo tipo de servico.
- Upload/registro de documentos obrigatorios.
- Status: rascunho, aguardando documentos, aguardando vistoria, aprovado, reprovado, suspenso.
- Cadastro de servicos oferecidos.
- Cadastro de disponibilidade, preco e regras operacionais.
- Visualizacao de reservas e servicos contratados.
- Notificacao de nova reserva/pre-check-in.
- Confirmacao de execucao de servico adicional.

Funcionalidades de gestao ParkHere:

- Separar acesso administrativo por papel: super admin, admin de usuarios/suporte, admin de parceiro e operador.
- Configurar taxas por categoria.
- Aprovar documentos.
- Agendar/registrar vistoria.
- Publicar ou suspender parceiro.
- Destacar estabelecimentos em divulgacao.

## Check-in E Checkout

MVP:

- App gera/valida estado de sessao.
- Portaria pode validar reserva.
- Checkout calcula valor final conforme plano.
- Vagas disponiveis sao atualizadas por eventos de entrada e saida.

V2:

- Leitura de placa.
- Reconhecimento facial.
- Cameras e dispositivos integrados por eventos.
- Validacao automatica com fallback manual.
