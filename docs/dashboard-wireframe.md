# Dashboard da operação — proposta visual

> Wireframe de aprovação antes da implementação. O canvas externo não ficou
> disponível nesta sessão porque a conexão do Figma exige reautenticação; este
> arquivo mantém a mesma proposta em formato revisável e será a referência
> para o próximo bloco de UI.

## Prévia Adobe

A prévia visual foi criada no Adobe Firefly Boards:
[abrir canvas do dashboard](https://firefly.adobe.com/boards/id/urn:aaid:sc:US:3ad00378-0a86-4d03-ad3f-9fa098a927bb).

A versão mais recente foi editada sobre a mesma arte no Adobe, sem criar um
novo canvas. Ela usa exclusivamente a paleta do app (navy, azul ParkHere,
ciano e branco), mostra matriz/filiais separadamente e inclui os indicadores
que o endpoint agregado fornece. Ela é somente uma referência visual para
aprovação. A tela do aplicativo não foi alterada nesta etapa.

## Estrutura responsiva

```mermaid
flowchart TB
  H[Barra: Visão geral · período · unidade · serviço · exportar]
  K[KPI: reservas | faturamento | ticket médio | parceiros ativos]
  A[Reservas por serviço\nEstacionamento · Guia · Hotel]
  B[Comparativo de unidades\nmatriz e filiais]
  C[Tendência mensal\nreservas e receita]
  D[Rentabilidade por modalidade\nhora · diária · semanal · mensal]
  E[Origem dos clientes\ncidades com maior demanda]
  F[Insights\npreço, ocupação e promoções]
  O[Operação\nfuncionários, turnos e cobertura]
  H --> K
  K --> A
  K --> B
  A --> C
  B --> D
  C --> E
  D --> F
  E --> F
  F --> O
```

No celular, a barra de filtros vira um botão que abre um painel inferior; os
cards de KPI ficam em carrossel horizontal; gráficos e insights são empilhados
em uma coluna; nenhuma tabela exige rolagem horizontal. No tablet e web, os
blocos usam duas colunas e o mapa de cidades ocupa a área principal.

## Regras de dados

- Todos os números vêm dos endpoints administrativos, com filtro por parceiro,
  unidade, serviço e período.
- O gráfico de modalidades compara receita líquida, quantidade e ocupação;
  sugestões de preço são recomendações identificadas como análise, nunca
  alteração automática de tarifa.
- Cidades de origem são agrupadas pela cidade do cliente e exibidas no mapa
  somente quando houver reservas no período.
- O dashboard é um entitlement pago. O admin pode conceder uma avaliação de
  30 dias; a API continua sendo a fonte de verdade da liberação.

## Próximo bloco de implementação

1. Endpoint agregado com os filtros acima e auditoria do usuário que consultou.
2. Estado de carregamento, vazio e erro padronizado pela central de feedback.
3. Componentes de gráfico acessíveis e responsivos.
4. Controle de entitlement e concessão de teste de 30 dias no painel admin.
