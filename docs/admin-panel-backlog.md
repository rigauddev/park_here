# Backlog: gestão administrativa do ParkHere

Atualizado em 12/09/2026. Este documento preserva as regras comerciais e
separa o que já está ligado à API do que ainda exige implementação. Não usar
itens pendentes como funcionalidades disponíveis para cobrança.

## Regras de negócio acordadas

- Uma empresa parceira começa com um gestor e dois operadores incluídos.
- Cada unidade/filial ativa contratada acrescenta duas vagas de operador.
- Operadores adicionais podem ser solicitados em pacote ou individualmente;
  a aprovação administrativa acrescenta o total comprado à capacidade.
- O limite pode ser liberado por confirmação automática do pagamento ou por
  aprovação manual da equipe administrativa. A confirmação automática requer
  integração de pagamento e webhook conciliado.
- O primeiro serviço do parceiro está incluído. Unidades ou serviços adicionais
  terão preço definido no painel administrativo antes de poderem ser ativados.
- Taxas padrão são cadastradas pela equipe ParkHere. O parceiro pode ter taxa
  individual por categoria/serviço; quando configurada, ela substitui a taxa
  padrão daquele parceiro e serviço.
- O admin vê empresas parceiras e, ao abrir uma, seus usuários, unidades,
  serviços, limite de operadores, aprovação e taxas. Clientes do app ficam em
  uma listagem separada.
- Gestores de parceiro continuam responsáveis por criar/editar sua equipe e
  serviços operacionais. O admin pode consultar e suspender contas; ações
  administrativas precisam de trilha de auditoria.
- Não excluir empresas ou histórico operacional. Suspender/desativar preserva
  reservas, pagamentos e relatórios.

## Entregue neste bloco

- [x] Menu administrativo móvel separado do menu de cliente/parceiro.
- [x] Seções administrativas navegam de forma independente em mobile e web.
- [x] Autenticação aceita o superadministrador global sem `tenant_id`, mantendo
  a validação de papel e tenant para os demais usuários.
- [x] Lista administrativa parte das empresas (`tenants`) e inclui empresas sem
  `PartnerProfile` detalhado.
- [x] Lista de parceiros exibe usuários, unidades, serviços ativos e capacidade
  de operadores calculada por unidade e pacotes aprovados.
- [x] Detalhe do parceiro lista serviços de estacionamento e guia; o admin pode
  ativar/desativar esses serviços com validação do tenant.
- [x] Tela de detalhes mostra equipe, unidades e acesso às taxas individuais.
- [x] Taxas globais e substituições individuais por parceiro persistidas; o
  cálculo de pagamento usa substituição ativa, ou padrão global quando ausente.
- [x] Lista de clientes reais com busca e ação para suspender/reativar.
- [x] Usuário suspenso não inicia login nem pode usar token já emitido.
- [x] Erros de carregamento das seções são isolados para que uma API com falha
  não oculte dados carregados pelas outras.
- [x] Detalhes administrativos de parceiro exibem equipe, serviços e unidades
  reais; parceiros sem registros `parkings` não ganham unidades artificiais.
- [x] Unidade de estacionamento pode editar nome, endereço, cidade e
  coordenadas e configurar taxa ParkHere por categoria/serviço.
- [x] Taxa efetiva obedece unidade > parceiro > padrão global e a cobrança da
  reserva consulta essa mesma precedência.
- [x] Administração pode ajustar a base de operadores, mantendo separados os
  limites por unidade, ajustes manuais e pacotes adicionais aprovados.
- [x] Administração pode ativar/desativar funcionalidades por parceiro e
  cadastrar preço e periodicidade; mudanças são auditadas.
- [x] Catálogo de funcionalidades ligado às telas disponíveis: Financeiro Pro
  para estacionamento. Dashboard e caixa operacionais básicos permanecem
  incluídos; cotas de unidades e operadores são controladas em suas próprias
  rotas, sem duplicação na aba de funcionalidades.
- [x] Perfil `/partners/me` informa também os complementos desligados e seus
  preços, permitindo que Minha empresa mostre o estado real do acesso.
- [x] Financeiro Pro exibe dados reais de reservas e pagamentos quando liberado
  pela administração; gestores veem o estado/preço enquanto aguarda liberação.
- [x] Clientes e empresas podem ser suspensos com motivo; o motivo é enviado
  pelos templates de e-mail e a suspensão é auditada.
- [x] Editor de templates HTML em português e inglês para boas-vindas, MFA,
  desativação de usuário e desativação de parceiro; inclui logo inline e slogan.
- [x] API de auditoria administrativa registra ações de taxas globais e por
  unidade/parceiro, capacidade, funcionalidades, suspensão, análise de pacotes,
  ativação de serviços e edição de templates.

## Próximas tarefas

### Gestão de parceiros e catálogo

- [ ] Adicionar pesquisa paginada no servidor e filtros por categoria, status,
  cidade/unidade e situação documental.
- [ ] Completar detalhes de parceiro com documentos, aprovações e histórico
  operacional; hoje a tela lista equipe, serviços e unidades.
- [ ] Permitir aprovar, reprovar, suspender e reativar parceiros com motivo,
  autor e data registrados.
- [ ] Criar catálogo genérico para lava-jato, hotel, restaurante, turismo e
  transporte conforme os módulos forem adicionados; incluir auditoria nas
  mudanças de status de serviço.
- [ ] Permitir editar dados de usuário parceiro e associá-lo às unidades na
  tela administrativa, respeitando isolamento multi-tenant.
- [ ] Implementar preço de unidade adicional e cobrança antes de ativar a filial.
- [ ] Implementar regra de um serviço incluído e preço para serviço adicional,
  com entitlements e validação no backend (não somente no Flutter).

### Usuários e capacidade

- [ ] Adicionar paginação, filtros por tenant/papel/status e exportação segura
  para usuários parceiros e clientes.
- [ ] Exibir detalhe do cliente com reservas, pagamentos e veículos com acesso
  restrito e registro de consulta; não expor dados de cartão.
- [x] Permitir ajuste administrativo auditado de capacidade de operadores,
  distinguindo capacidade base, pacotes aprovados e ajuste manual.
- [ ] Garantir idempotência e conciliação de pagamento de pacotes de operadores
  e unidades antes de liberar capacidade automaticamente.

### Taxas, planos e auditoria

- [ ] Definir catálogo, moeda, vigência e limites de taxas/planos; registrar
  versões para que pagamentos antigos mantenham o snapshot que foi aceito.
- [x] Adicionar log administrativo para alteração de taxas, suspensão de conta,
  edição de unidade, funcionalidades, capacidade, pacotes e serviços.
- [ ] Exibir os logs administrativos na tela do app e acrescentar filtros por
  parceiro, autor, ação e período.
- [x] Criar gestão inicial de funcionalidades pagas por parceiro, com ativação,
  preço e periodicidade editáveis.
- [ ] Registrar origem da liberação (plano, pagamento, teste ou concessão),
  período de vigência e histórico de revogação.
- [ ] Ligar preços das funcionalidades à solicitação, cobrança e conciliação
  financeira; o painel hoje registra preço e liberação administrativa, mas não
  cobra automaticamente.
- [ ] Implementar a camada de gráficos/indicadores avançados do dashboard e sua
  API antes de adicionar `advanced_dashboard` ao catálogo de complementos.
- [ ] Definir e validar cotas de serviços adicionais antes de oferecer esse
  recurso como item pago; hoje não existe bloqueio de capacidade associado.
- [ ] Criar vínculo genérico de afiliado entre guia, parceiro e serviço. O fluxo
  entregue hoje usa `GuideParkingLink`; não modelar hotéis, lava-jatos ou outros
  serviços como estacionamentos para contornar essa limitação.
- [ ] Guardar preferência de idioma no perfil do usuário para enviar e-mails de
  sistema no idioma escolhido. Templates existem em `pt_BR` e `en`; os envios
  atuais usam português como padrão.

### Qualidade e publicação

- [ ] Adicionar testes de API para autorização `SUPER_ADMIN`, isolamento,
  precedência global/individual de taxas e bloqueio de contas inativas.
- [ ] Criar teste integrado autenticado para listagem e gestão de parceiro e
  cliente usando seed local.
- [ ] Localizar todas as telas administrativas em português e inglês.
- [ ] Revisar responsividade em celular, tablet e web; testar menu e diálogos em
  telas estreitas.
- [ ] Registrar snapshots de taxas em comprovantes e reserva quando houver
  alteração posterior de configuração.
