# Agentes E Skills

## Objetivo

As skills locais dao contexto repetivel para agentes IA trabalharem no ParkHere sem redescobrir o produto a cada tarefa.

## Skills Criadas

- `parkhere-product-owner`: requisitos, regras, roadmap e criterios de aceite.
- `parkhere-backend-api`: FastAPI, SQLAlchemy, Alembic, contratos e multi-tenancy.
- `parkhere-flutter-app`: Flutter, Riverpod, features e UX do motorista.
- `parkhere-qa-reviewer`: revisao tecnica, riscos, testes e regressao.

## Como Usar Em Prompts

```text
Use $parkhere-product-owner para transformar a ideia de servicos adicionais em requisitos do MVP.
Use $parkhere-backend-api para criar os endpoints de reserva e check-in manual.
Use $parkhere-flutter-app para integrar a tela de mapa com o endpoint de estacionamentos.
Use $parkhere-qa-reviewer para revisar a mudanca antes do commit.
```

## Fluxo Recomendado Com Agentes

1. Product Owner define escopo e aceite.
2. Backend implementa contratos e persistencia.
3. Flutter consome os contratos.
4. QA revisa riscos, testes e cenarios reais.
5. Git registra em branch curta.

## Observacao

A pasta `.agents` local esta protegida neste ambiente. Por isso, as skills foram criadas em `agents/skills/`, dentro do reposititorio.

