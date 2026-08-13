# Gestao De Parceiros E Estabelecimentos

## Status Atual

Hoje a gestao existe apenas como base tecnica:

- `tenants` representam estabelecimentos/contas parceiras.
- `PARKING_ADMIN` representa dono/admin de estacionamento.
- `/auth/register-parking` cadastra um estacionamento inicial.
- `parkings` e `parking_services` ja existem para alimentar o app do motorista.

Ainda nao existe painel completo de gestao para parceiros.

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
