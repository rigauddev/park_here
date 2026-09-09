# Politica De Sessao E Token

## Decisao Atual

- Access token do ParkHere expira em 6 horas (`ACCESS_TOKEN_EXPIRE_MINUTES=360`).
- Quando o app abrir com token expirado, deve limpar a sessao local e exigir novo login.
- Quando a API responder `401 Unauthorized` em rota autenticada, o app deve fazer logout automatico.
- Refresh token permanece como desenho futuro; nao devemos simular refresh com token falso em producao.

## Referencias Consultadas

Consulta realizada em 2026-08-14:

- OWASP Session Management Cheat Sheet: recomenda timeout absoluto conforme o tempo esperado de uso e cita faixa de 4 a 8 horas para aplicacoes usadas durante um periodo de trabalho.
- NIST SP 800-63B: separa timeout geral e timeout de inatividade; para niveis mais altos, recomenda reautenticacao periodica e timeout por inatividade.

## Proximos Blocos

- Criar timeout de inatividade no backend/app.
- Implementar refresh token real com rotacao e revogacao.
- Criar historico de sessoes e botao para encerrar sessoes antigas.
- Adicionar aviso antes de expirar sessao quando o app estiver ativo.
