# Seed de homologação

O seed local cria um cenário pequeno e repetível para os testes manuais:

- um parceiro de estacionamento e um estacionamento 24 horas em Valença-BA;
- três operadores, um gestor, um cliente e um administrador do sistema;
- veículo e cartão de teste do cliente;
- um parceiro de locação de veículos separado, com três veículos e dois planos;
- dois parceiros de guia turístico aprovados e afiliados ao estacionamento de Valença;
- escala de três operadores e taxas fictícias de homologação;
- nenhum estacionamento de outras cidades e nenhuma reserva inicial.

Para recriar o banco de dados de teste (a migração deve estar aplicada):

```bash
docker compose up -d mysql api
docker compose exec -T api python -m app.scripts.seed_mvp_data
```

Todos os usuários usam a senha `123456`:

| Perfil | E-mail |
| --- | --- |
| Admin do sistema | `admin@parkhere.test` |
| Gestor | `gestor@parkhere.test` |
| Operadores | `operador1@parkhere.test`, `operador2@parkhere.test`, `operador3@parkhere.test` |
| Cliente | `cliente@parkhere.test` |

Locação e guias:

| Perfil | E-mail |
| --- | --- |
| Gestor da locadora | `gestor.locadora@servicehub.test` |
| Guia turístico 1 | `guia1@servicehub.test` |
| Guia turístico 2 | `guia2@servicehub.test` |

Os valores são fictícios e o provedor de pagamento continua simulado até as
credenciais e o webhook de homologação serem configurados.
