# Testes manuais locais

## Android fisico por USB

Habilite depuracao USB, autorize o computador no aparelho e mantenha o cabo conectado.
Com a API local na porta 8000, execute na raiz:

```sh
bash scripts/run_android_usb.sh ZF524HQSZV
```

O script configura `adb reverse` e passa a URL por `--dart-define`, sem alterar `.env`.
`10.0.2.2` e o endereco especial do emulador; no aparelho fisico usamos o tunel USB.
Ao desconectar/reconectar, execute novamente o script. Nao e necessario estar no mesmo Wi-Fi.

## Web

```sh
cd parkhere_user_app
flutter run -d chrome --web-port 8080 --dart-define=API_URL=http://localhost:8000
```

Abra http://localhost:8080. Mantenha o processo Flutter em execucao.
Se uma aba antiga ficar branca, teste a janela aberta pelo Flutter e recarregue a
aba antiga sem cache. Persistindo, registre a URL, o comando utilizado e o primeiro
erro vermelho do console do navegador; nao apague os dados de sessao antes de registrar o erro.

Em 06/09/2026, a tela de login foi verificada por captura do Chrome em execucao debug.
A tela branca relatada nao foi reproduzida nessa sessao; nao ha causa raiz confirmada.

## Roteiro

1. Entrar como cliente e testar cidade, busca e detalhes do estacionamento.
2. Selecionar veiculo, vaga e servicos; conferir valores e previsao de chegada.
3. Criar e cancelar pre-reserva; conferir liberacao da vaga.
4. Entrar como parceiro/operador e testar reserva na vaga escolhida, caixa,
   check-in e checkout, respeitando as permissoes de cada papel.
5. Conferir que um parceiro nao acessa o estacionamento do outro.

Para cada falha, informar papel do usuario, tela, passos, resultado esperado e
resultado observado. Fotos podem ajudar, evitando senhas, tokens e dados de cartao.
Pagamentos desta fase sao simulados; nao transferir dinheiro para QR demonstrativo.
