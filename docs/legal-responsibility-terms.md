# Termos de responsabilidade MVP — referência interna

Este documento orienta os textos de aceite do ParkHere. Nao substitui revisao juridica. Ver tambem [minutas por categoria](legal-service-terms-draft.md) e a skill [parkhere-legal-review](../agents/skills/parkhere-legal-review/SKILL.md). Os termos ainda devem ser revisados por advogado brasileiro antes de uso público.

## Bases Consultadas

- Codigo de Defesa do Consumidor, especialmente responsabilidade por servico.
- Sumula 130 do STJ sobre responsabilidade por dano ou furto de veiculo em estacionamento.
- LGPD para dados pessoais, documentos, localizacao, imagens e biometria.
- Orientacao ANPD sobre legítimo interesse e direitos do titular.

Fontes:

- https://www.planalto.gov.br/ccivil_03/leis/l8078compilado.htm
- https://arquivocidadao.stj.jus.br/index.php/sumula-130
- https://www.planalto.gov.br/ccivil_03/_ato2015-2018/2018/lei/L13709compilado.htm
- https://www.gov.br/anpd/pt-br/centrais-de-conteudo/materiais-educativos-e-publicacoes/guia_orientativo_hipoteses_legais_tratamento_de_dados_pessoais_legitimo_interesse
- https://www.gov.br/anpd/pt-br/canais_atendimento/cidadao-titular-de-dados/denuncia-peticao-de-titular-referente-lgpd
- https://www.stj.jus.br/sites/portalp/Paginas/Comunicacao/Noticias/08042021-Site-de-comercio-eletronico-nao-e-responsavel-por-fraude-praticada-fora-da-plataforma.aspx

## Posicionamento da plataforma e aceite na reserva

ParkHere pode informar que conecta cliente e prestador e facilita a descoberta, solicitação, reserva e comunicação. O texto não deve declarar que a plataforma nunca responde por problemas do serviço: o papel real, publicidade, cobrança, suporte e participação em cada operação importam, e direitos do consumidor não podem ser afastados por aceite genérico. A redação atual e cada contrato de categoria devem passar por revisão jurídica.

No momento da reserva, identificar o prestador e apresentar condições de cada serviço contratado. O backend persiste snapshot localizado/versionado e timestamp em cada reserva (`terms_accepted_at`, `terms_version`, `terms_locale`, `accepted_terms_snapshot`). Marketing personalizado é separado do aceite necessário à reserva.

## Aceite Do Cliente Ao Criar Conta

O cliente deve aceitar que:

- Dados pessoais, documentos, veiculos, localizacao e meios de pagamento serao tratados para cadastro, reserva, check-in, checkout, pagamento, suporte e seguranca.
- Informacoes de reserva serao compartilhadas com o estabelecimento responsavel pela execucao do servico.
- O usuario deve informar dados verdadeiros, manter documentos e veiculos atualizados e respeitar regras do estabelecimento.
- Servicos adicionais contratados seguem disponibilidade, preco e politicas informadas no app.
- Biometria, reconhecimento facial, placa e cameras ficam condicionados a consentimento especifico quando forem habilitados.

## Aceite Do Cliente No Check-In

Antes de confirmar check-in, o cliente deve aceitar que:

- Confere dados da reserva, veiculo, placa, periodo, valores e servicos adicionais.
- Autoriza o registro operacional do check-in, incluindo data, hora, localizacao aproximada e fotos do veiculo quando exigidas.
- Deve retirar pertences de valor ou declarar/registrar itens quando houver politica especifica.
- O estabelecimento continua responsavel pela prestacao segura do servico nos limites da legislacao aplicavel.
- Cancelamento, permanencia excedente, danos e servicos extras podem gerar cobrancas conforme regras exibidas no app.

## Aceite Do Parceiro Ao Criar Conta

O parceiro deve aceitar que:

- Informacoes cadastrais, documentos, alvara, dados bancarios, fotos e dados dos responsaveis serao usados para aprovacao, vistoria, operacao e repasse.
- O estabelecimento so sera publicado apos aprovacao documental e vistoria quando aplicavel.
- Deve manter vagas, tarifas, servicos, horarios, portaria, seguranca e disponibilidade atualizados.
- Deve cumprir as reservas recebidas pelo app e registrar check-in/checkout corretamente.
- Deve cumprir CDC, normas locais, LGPD e regras de tratamento de dados dos clientes.
- Operadores criados pelo parceiro atuam em nome do estabelecimento.

## Aceite Ao Criar Operador

O parceiro dono/gestor deve aceitar que:

- O operador tera acesso operacional simplificado.
- O operador pode visualizar reservas, mapa de vagas, pagamentos, check-in e checkout manual.
- O operador nao pode alterar tarifas, dados cadastrais, taxas, financeiro ou configuracoes administrativas.
- O parceiro e responsavel por remover usuarios que nao trabalham mais no estabelecimento.
- O plano atual inclui 2 operadores; acima disso pode haver taxa adicional.

## Aceite Para Reconhecimento Facial V2

Antes de qualquer biometria:

- Consentimento deve ser especifico, destacado e opcional.
- Deve existir alternativa manual sem biometria.
- Deve haver politica de retencao, finalidade, seguranca, revogacao e auditoria.
- Dados biometricos devem ser tratados como dados sensiveis.

## Cancelamento e reembolso de reservas pagas

- O endpoint de cancelamento atual não executa reembolso. O valor `cancellation_credit_amount` não é dinheiro devolvido nem confirmação de estorno.
- O CDC prevê direito de arrependimento de sete dias para contratação fora do estabelecimento comercial, incluindo contratação eletrônica. A aplicação a cada categoria, início da execução do serviço, cálculo de prazo e eventual devolução parcial deve ser validada por advogado antes de publicar uma política ou descontar taxas.
- O prazo operacional de três dias úteis para análise é um SLA de resposta da plataforma; ele não deve reduzir ou suspender direitos legais nem atrasar devolução que a lei determine.
- Antes de ativar cobrança de taxa por cancelamento/reembolso, a tela deve mostrar valor pago, fundamento e valor estimado a devolver. Uma taxa só pode ser efetivada após revisão da política aplicável e aprovação jurídica.

Referência primária: [Código de Defesa do Consumidor, art. 49 (Planalto)](https://www.planalto.gov.br/ccivil_03/leis/l8078compilado.htm). Esta nota é triagem de produto, não parecer jurídico; validar com advogado brasileiro.
