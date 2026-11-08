# Seed de homologação

O seed local cria um cenário pequeno e repetível para os testes manuais:

- um parceiro de estacionamento e um estacionamento 24 horas em Valença-BA;
- três operadores, um gestor, um cliente e um administrador do sistema;
- veículo e cartão de teste do cliente;
- um parceiro de locação de veículos separado, com três veículos e dois planos;
- dois parceiros de guia turístico aprovados e afiliados ao estacionamento de Valença;
- uma empresa multi-serviço com estacionamento e locadora de carros/moto na mesma conta;
- escala de três operadores e taxas fictícias de homologação;
- nenhum cenário inicial de reserva;
- uma unidade de estacionamento e uma locadora em Cotia-SP, no endereço
  Avenida Doutor Odair Pacheco Pedroso, 1393, com coordenadas de referência
  `-23.628874, -46.909681`, além de gestor e operador próprios. Essa unidade
  valida a busca manual por cidade e a descoberta de serviços em raio de 10 km.

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
| Gestor da empresa híbrida | `gestor.mobilidade@servicehub.test` |
| Gestor de Cotia | `gestor.cotia@servicehub.test` |
| Operador de Cotia | `operador.cotia@servicehub.test` |
| Guia turístico 1 | `guia1@servicehub.test` |
| Guia turístico 2 | `guia2@servicehub.test` |

Os valores são fictícios e o provedor de pagamento continua simulado até as
credenciais e o webhook de homologação serem configurados.
