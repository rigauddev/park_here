# Testes Manuais MVP

Use este roteiro para validar busca, reserva, caixa, check-in, checkout, tenant e
compensacao de taxas do ParkHere.

## Reset local

Apagar banco, subir containers, aplicar migrations e rodar seed:

```bash
docker compose down -v
docker compose up -d mysql api
docker compose exec -T api alembic upgrade head
docker compose exec -T api python -m app.scripts.seed_mvp_data
docker compose up -d web
```

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

## Entitlements administrativos e Financeiro Pro

1. Entre como administrador do sistema e abra **Parceiros → Funcionalidades**.
2. Selecione um estacionamento. Confirme que há somente `Financeiro Pro` no
   catálogo atual; unidades e operadores continuam nos controles de capacidade.
3. Configure o módulo como pago, informe valor e periodicidade, mas mantenha-o
   desativado. Salve e confira que a ação aparece na auditoria administrativa.
4. Entre como gestor desse estacionamento, abra **Minha empresa** e toque em
   **Financeiro Pro**. O app deve mostrar preço e estado bloqueado; o caixa
   básico e dashboard continuam disponíveis.
5. Volte ao admin e habilite o complemento. Atualize o perfil do parceiro e
   abra Financeiro Pro. Deve carregar o relatório real de reservas, recebidos,
   taxas administrativas e filtros de período.
6. Repita com operador: o menu Financeiro Pro não aparece e uma chamada direta
   autenticada a `GET /partners/financial-report` deve retornar `403`.
7. Repita com guia ou outra categoria sem módulo financeiro conectado: a aba
   administrativa deve informar que ainda não há complemento liberável.
8. Confirme que não houve cobrança automática: preço e entitlement já são
   administráveis, mas solicitação, pagamento e vigência ainda aguardam a
   integração financeira.
