# Testes Manuais MVP

Use este roteiro para validar busca, reserva, caixa, check-in, checkout, tenant e
compensacao de taxas do ParkHere.

## Preparar a homologação local sem apagar o banco

O seed é repetível e não exige remover o volume MySQL. Após criar/recriar o
banco, aplique migrations e carregue os cenários de teste:

```bash
docker compose up -d mysql api
docker compose exec -T api alembic upgrade head
docker compose exec -T api python -m app.scripts.seed_mvp_data
docker compose up -d --build web
```

`docker compose down -v` apaga permanentemente o banco local e os arquivos
temporários. Use somente quando quiser zerar intencionalmente o ambiente de
desenvolvimento; ele não é necessário para atualizar o seed.

URLs:

- App web: http://localhost:8080
- API: http://localhost:8000
- Swagger: http://localhost:8000/docs
- MySQL host local: `localhost:3307`

Contas seed:

- Cliente: `cliente@parkhere.test` / `123456`
- Parceiro gestor: `admin@parkhere.test` / `123456`
- Parceiro dono: `parceiro@parkhere.test` / `123456`
- Operador: `operador@parkhere.test` / `123456`
- Guia turístico: `guia@parkhere.test` / `123456`
- MFA local: `000000`

Para testar indicação de guia, cadastre um usuário parceiro com serviço `Guia
turístico`, configure as comissões da unidade, solicite afiliação e aprove o
pedido no usuário gestor.

O seed cadastra `guia@parkhere.test` como parceiro independente, com tenant e
perfil próprios, afiliado ao estacionamento principal. A
lista do guia mostra as ofertas por diária, semanal, mensal e longa duração antes
de solicitar novas afiliações. A taxa da plataforma padrão para a comissão do
guia é 20%; o guia vê o valor líquido e o estacionamento vê o bruto, a taxa e o
líquido.

Fluxo de indicação atualizado:

1. Na conta gestora, abra **Afiliação e comissões**, escolha a unidade e defina
   comissões positivas para diária, semanal, mensal e longa duração; só então
   ative **Aceitar guias afiliados**.
2. Na conta do guia, abra **Estacionamentos**, confira a oferta e solicite
   afiliação. Na conta gestora, aprove o pedido.
3. Na conta cliente, escolha estacionamento e plano; selecione o guia no campo
   opcional de indicação, sem marcar o extra pago de passeio/guia.
4. Conclua a reserva, check-in, pagamento e checkout. A reserva mantém o guia
   indicado e a comissão congelada; o dashboard do guia conta repasse apenas
   após a reserva chegar a `completed`.

## Android fisico por USB

Com a API local na porta 8000:

```bash
bash scripts/run_android_usb.sh ZF524HQSZV
```

O script configura `adb reverse` e passa `API_URL=http://127.0.0.1:8000` por
`--dart-define`. Execute novamente se desconectar o cabo.

## Fluxo completo cliente, guia e estacionamento

1. Entre como cliente e faça login; confira que os estacionamentos próximos à
   localização são listados.
2. Cadastre um veículo e confirme em `Veículos` que ele continua salvo após sair
   e entrar novamente. Cadastre um cartão na carteira.
3. Pesquise `Valença`, selecione um estacionamento e escolha um plano. Para
   diária, informe a quantidade de dias.
4. Faça uma reserva sem indicação: abra a rota, escolha um aplicativo de mapas,
   confirme a pré-reserva e verifique a validade como tempo estimado + 5 minutos.
5. Volte para `Reservas`, faça check-in com validação de localização e fotos,
   pague com o cartão salvo ou Pix simulado e confirme que a pré-reserva virou
   reserva ativa.
6. Faça checkout e confirme o status finalizado, horário, fotos temporárias e
   atualização da vaga.
7. Repita o fluxo selecionando o serviço de guia e um guia afiliado. Confira no
   resumo e na API o `guide_user_id` e a comissão congelada.
8. Repita escolhendo `Sem indicação` e confirme que a reserva não possui comissão
   de guia.
9. Cancele uma pré-reserva não paga e confirme que a vaga volta a ficar livre.

## Fluxo parceiro

1. Entre como parceiro gestor.
2. Use o botao da barra superior para ocultar o menu; os icones devem continuar
   visiveis e navegaveis.
3. Abra `Minha empresa`, edite um estacionamento e confira a tolerancia de
   chegada, tipos de vaga, tarifas e servicos.
4. Abra `Mapa de vagas`, escolha uma vaga livre e crie reserva para cliente que
   chegou direto ao estacionamento.
5. Informe placa e telefone do proprietario; com `Cliente ja esta no
   estacionamento`, o backend deve gravar a hora atual como inicio da reserva.
6. Receba em dinheiro e confira o troco.
7. Abra `Taxas e compensacoes` e confirme a taxa pendente referente a reserva
   recebida em dinheiro.
8. Crie a proxima reserva paga por Pix; o extrato deve mostrar o abatimento da
   taxa pendente no repasse online.

## Fluxo operador

1. Entre como operador.
2. Confirme que o menu mostra apenas operacao: mapa de vagas, reservas recebidas
   e perfil.
3. Crie uma reserva no mapa usando placa e telefone.
4. Receba Pix ou dinheiro no caixa da vaga.
5. Confirme que `Minha empresa`, `Usuarios`, `Financeiro Pro` e `Taxas e
   compensacoes` nao ficam disponiveis para operador.

## Validacoes de risco

- Duas tentativas simultaneas na mesma vaga devem gerar apenas uma reserva; a
  outra deve falhar com `409 Spot already reserved`.
- Parceiro de outro tenant nao pode listar, pagar ou cancelar reserva fora do seu
  estacionamento.
- Reserva cancelada ou expirada nao pode gerar novo pagamento.
- Repetir confirmacao de Pix/dinheiro ja pago nao deve duplicar taxa nem
  compensacao.
- Pagamentos desta fase sao simulados; QR code exibido no app nao transfere
  dinheiro real.

## Testes automatizados opcionais

Unitarios backend:

```bash
docker compose exec -T api python -m unittest discover -s tests -q
```

Fluxo completo HTTP/MySQL:

```bash
docker compose exec -T -e RUN_PILOT_HTTP=1 api python -m unittest discover -s tests -p test_pilot_http.py -v
```

## Funcionalidades, cotas e aprovações administrativas

1. Entre como admin do sistema e abra **Funcionalidades**. Selecione um parceiro
   estacionamento e confira dashboard, unidades, mapa/reservas, serviços,
   equipe, afiliações, caixa básico, Financeiro Pro, unidade adicional e serviço
   adicional. Para guia, confira dashboard, serviços, afiliações e serviço extra.
2. Configure `Financeiro Pro` como pago, informe valor e periodicidade, mantendo
   desativado. Entre como gestor e toque no card. Deve abrir o resumo com preço,
   cadeado e botão **Solicitar liberação**.
3. Envie a solicitação. Confira estado pendente em **Minha empresa** ao reabrir
   a funcionalidade e no painel admin em **Aprovações**. Não deve ocorrer débito.
4. Aprove o pedido como admin; atualize o perfil e abra o Financeiro Pro. Deve
   carregar dados reais de reservas, valores recebidos e taxas administrativas.
   Confirme o registro em auditoria.
5. Faça o mesmo para `additional_services`: cadastre o primeiro serviço sem
   custo; tente incluir outro e confira o popup com valor. A API deve rejeitar
   cadastro acima da capacidade até que a solicitação seja aprovada. Após
   aprovação, o segundo serviço deve ser salvo.
6. Faça o mesmo para `additional_units`. Antes da aprovação, o primeiro
   estacionamento deve ser criado e o próximo deve abrir o pedido de unidade.
   Depois de aprovar, crie a unidade e confira que a cota de dois operadores
   daquela unidade continua obedecendo a regra existente.
7. Confira caixa básico sem complemento Pro. Depois habilite Pro e confirme que
   o relatório detalhado abre. Operador não deve ter acesso aos controles de
   gestão nem ao Financeiro Pro.
8. Configure uma função como gratuita e desativada: o app deve mostrar bloqueio
   e instrução para procurar a equipe, sem exibir botão de compra. Reative-a no
   admin e valide o acesso.
9. Confirme que a decisão manual não representa pagamento confirmado. Ativação
   automática, cobrança, webhook e vigência continuam pendentes da integração
   Mercado Pago.
# Aceite e privacidade antes de reservar

- Inicie uma reserva em português e confirme que os termos do estacionamento e dos serviços escolhidos aparecem antes de abrir o app de mapas.
- Tente continuar sem marcar o aceite; a reserva/pré-reserva não deve ser criada.
- Marque aceite e conclua; confira que a resposta da API contém `terms_accepted_at`, `terms_version`, `terms_locale` e snapshot `accepted_terms` com plataforma, estacionamento e cada serviço selecionado.
- Repita em inglês e confirme que os textos e `terms_locale=en` correspondem ao idioma selecionado.
- Simule app antigo enviando versão anterior; API retorna `409` e a tela precisa solicitar novo aceite.
- Na reserva operacional, o operador deve visualizar os termos do estacionamento e confirmar que o cliente os revisou antes de criar.
- Aceite de marketing personalizado deve permanecer opcional, separado de reserva e conta, desmarcado por padrão e revogável em preferências. Esse controle ainda deve ser desenvolvido antes de qualquer segmentação de anúncios.

## Unidades, escalas e acesso do operador

- Associe um operador à matriz e a uma filial. Feche e reabra os detalhes do
  operador; as duas unidades devem continuar selecionadas. E-mail e CPF devem
  aparecer como dados de consulta, sem edição.
- Crie uma escala numa unidade sem operadores associados. O calendário deve
  continuar visível e os turnos devem ser criados como vagas abertas para
  atribuição posterior.
- Associe um operador à unidade e gere um turno. Tente criar para o mesmo
  operador um turno sobreposto em outra unidade; a API deve rejeitar com `409`.
- Em um dia sem turno, confirme que a tela ainda mostra o calendário e a
  mensagem de que não há turnos naquele dia.
- Entre como operador sem turno ativo: somente Escala, Perfil e Conta de repasse
  ficam disponíveis. Mapa, reservas e demais rotas operacionais devem ficar
  bloqueadas. Durante o turno, mapa e reservas devem mostrar a unidade escalada.
- Gere uma escala e confirme que a animação de progresso aparece até o servidor
  concluir a operação; teste também a criação de uma escala para filial.
- Envie um template de e-mail com cabeçalho customizado sem imagem e confirme
  que o e-mail recebido ainda exibe o logo inline do ParkHere.

O seed também recria a matriz `ParkHere Valenca VIP` e a filial
`ESTACIONAMENTO TESTE` na mesma empresa, com os IDs de unidade já usados no
ambiente de teste. O gestor é `gestor.valenca.vip@parkhere.test` e o operador
compartilhado entre unidades é `operador.valenca.vip@parkhere.test`; senha
`123456`, MFA local `000000`. Um segundo operador de filial é
`operador.valenca.filial@parkhere.test`.

Para validar cobertura, o seed cria para dois dias após sua execução um turno
da matriz atribuído ao operador compartilhado e um turno aberto sobreposto na
filial. No dia seguinte há um turno de filial atribuído ao segundo operador.
Na tela de escala, use as visões mês/semana, selecione o turno aberto e tente
atribuir o operador compartilhado: a API deve recusar a colisão entre unidades
com `409`. O segundo operador deve ser aceito. Edite horários, atualize a tela e
confira que a alteração persiste e entra no histórico. O seed não apaga escalas
manuais nem reserva; ele mantém estes turnos-fixture identificados por unidade
e horário.

## Checkout com excedente e cancelamento

- Crie uma pré-reserva de teste, pague, faça check-in e deixe o horário passar.
  O checkout deve consultar a API; a resposta `402` deve apresentar minutos e
  valor do excedente calculados no backend. Pague o propósito
  `checkout_excess`, tente novamente e confira status finalizado e vaga liberada.
- Na lista recebida do parceiro, uma reserva em permanência com atraso deve
  apresentar tempo excedido e valor atualizado. Confira especialmente a tarifa
  adicional da categoria da vaga.
- Cliente pode cancelar somente pré-reserva não paga e ainda em estado
  `pre_reserved`. Reserva confirmada/paga não pode ser cancelada por esse botão;
  deve aguardar o módulo de pedido de reembolso.
- Confira número de exibição `PH-XXXXXXXX` nos cards/detalhes e ordenação por
  criação mais recente. O UUID continua como chave técnica.
- A carteira de teste mostra cartões em cartões visuais empilhados e oferece
  bandeira, titular, número e validade. Persistência atual é apenas local e
  guarda metadados mascarados; não testar cobranças reais com cartão digitado.
- O fluxo formal de reembolso (motivo, anexo opcional, prazo de três dias úteis,
  decisão auditada e estorno no provedor) ainda não está implementado. Não
  anunciar o valor de `cancellation_credit_amount` como dinheiro estornado.
