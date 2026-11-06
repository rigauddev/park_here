# Visao Do Produto

## Proposta

ServiceHub conecta clientes a serviços locais em uma única conta. O primeiro
conjunto de módulos é estacionamento, locação veicular e guia turístico; novos
serviços entram como módulos independentes sem misturar seus inventários.

## Publicos

- Motorista: busca vaga, compara preco/servicos, reserva, paga, faz check-in e checkout.
- Parceiro/estabelecimento: entra como estacionamento, lava-jato, hotel, restaurante, turismo ou outro prestador aprovado.
- Estacionamento: cadastra unidade, vagas, precos, servicos e operadores.
- Lava-jato parceiro: cadastra servico para ser executado dentro de estacionamentos habilitados.
- Operador/portaria: valida entrada e saida, resolve incidentes e atualiza disponibilidade.
- Admin ParkHere: acompanha tenants, planos, suporte e metricas.

## Principios Do MVP

- A vaga precisa refletir ocupacao real por check-in e checkout.
- Reserva deve expirar se o usuario nao chegar no prazo.
- Servicos adicionais devem ser opcionais e cobrados junto da reserva.
- Pagina inicial deve permitir idioma Portugues Brasil e Ingles.
- Login inicial deve separar entrada de cliente e parceiro.
- Todo estabelecimento parceiro precisa informar tipo de servico no cadastro.
- Todo estabelecimento parceiro precisa passar por analise documental e vistoria antes de ficar ativo.
- O app pode usar mock temporario, mas todo mock deve apontar o endpoint futuro.
- Automacao por placa/facial fica para V2, sem bloquear o MVP.

## Tipos De Parceiro E Serviços

- Estacionamento.
- Lava-jato.
- Hotel.
- Restaurante.
- Turismo/guia.
- O guia turístico é um parceiro independente: tem tenant, perfil e serviços próprios; pode também se afiliar a múltiplos parceiros para divulgar os serviços deles e receber a comissão ofertada pelo parceiro indicado.
- A identidade do afiliado nunca compartilha o tenant do parceiro indicado. A indicação referencia o usuário guia e o serviço/unidade de destino.
- Transporte.
- Outros servicos locais aprovados pela plataforma.

Uma mesma empresa/tenant pode contratar mais de um módulo. Cada módulo possui
unidades, usuários, permissões, reservas e relatórios próprios, enquanto o
gestor pode consultar um consolidado da conta e também filtrar por serviço,
matriz ou filial.

## Validacao De Parceiros

Antes de publicar um parceiro, a plataforma deve coletar e revisar:

- Dados cadastrais e responsavel legal.
- Documento pessoal do responsavel.
- CNPJ/CPF conforme tipo de prestador.
- Alvara ou documento equivalente quando aplicavel.
- Endereco e comprovacao do local.
- Vistoria do local para parceiros fisicos.
- Termos de execucao quando o servico ocorre dentro de estacionamento.

## Nome E Identidade

O codigo ainda usa `ParkFinder` em alguns pontos. Padronizar gradualmente para `ParkHere` em telas, API title, docs e pacotes quando for seguro.
