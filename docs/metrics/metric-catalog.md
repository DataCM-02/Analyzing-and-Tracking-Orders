# Catálogo de métricas

## Objetivo

Este documento define as métricas oficiais do ATOrders, incluindo fórmula, granularidade, critérios de elegibilidade e exclusões.

As mesmas regras deverão ser utilizadas no dbt, Power BI e estudos analíticos.

## Convenções gerais

- Timestamps serão armazenados em UTC.
- Durações serão calculadas inicialmente em horas corridas.
- As análises utilizarão um momento de referência explícito, chamado `analysis_at`.
- Pedidos cancelados serão excluídos das métricas de entrega, salvo indicação contrária.
- Contagens de pedidos utilizarão `count(distinct order_id)`.
- Tempos serão apresentados com mediana e percentil 90, além da média quando útil.
- Registros tecnicamente inválidos não entrarão nos marts oficiais.
- Toda métrica deverá ser reconciliável com seu modelo dbt de origem.

## Dimensões de análise

As métricas poderão ser segmentadas por:

- data;
- centro de distribuição;
- região;
- estado;
- transportadora;
- nível de serviço;
- etapa operacional;
- produto;
- categoria de produto;
- status do pedido.

## Pedidos criados

**Pergunta:** quantos pedidos foram registrados?

**Grão:** período.

**Fórmula:**

```text
count(distinct order_id)
```

**Data de referência:** `created_at`.

**Exclusões:** registros inválidos ou duplicados.

## Pedidos entregues

**Pergunta:** quantos pedidos concluíram a jornada?

**Grão:** período.

**Fórmula:**

```text
count(distinct order_id)
onde delivered_at não é nulo
```

**Data de referência:** `delivered_at`.

## Throughput

**Pergunta:** quantos pedidos avançaram ou foram concluídos durante o período?

### Throughput de entrega

```text
count(distinct order_id entregue no período)
```

### Throughput por etapa

```text
count(distinct order_id que concluiu a etapa no período)
```

O evento que representa a conclusão de cada etapa deverá ser documentado.

Exemplos:

| Etapa | Evento de conclusão |
|---|---|
| Pagamento | `payment_approved` |
| Alocação | `order_allocated` |
| Picking | `picking_completed` |
| Packing | `order_packed` |
| Expedição | `order_shipped` |
| Transporte | `order_delivered` |

## Backlog

**Pergunta:** quantos pedidos ainda não foram concluídos?

**Grão:** pedido no momento de referência.

Um pedido pertence ao backlog quando:

```text
created_at <= analysis_at
e delivered_at é nulo
e cancelled_at é nulo
```

**Fórmula agregada:**

```text
count(distinct order_id em aberto)
```

O backlog poderá ser agrupado pela etapa atual do pedido.

## Work in progress

No MVP, `work in progress` será tratado como o conjunto de pedidos que já iniciou o processamento operacional, mas ainda não foi entregue ou cancelado.

```text
payment_approved_at não é nulo
e delivered_at é nulo
e cancelled_at é nulo
```

O backlog pode incluir pedidos aguardando pagamento, enquanto o work in progress começa após a aprovação financeira.

## Aging total

**Pergunta:** há quanto tempo o pedido permanece aberto?

**Grão:** pedido.

Para pedidos abertos:

```text
total_aging_hours =
analysis_at - created_at
```

Para pedidos concluídos, o aging deixa de ser aplicado e utiliza-se o lead time total.

## Aging da etapa

**Pergunta:** há quanto tempo o pedido permanece na etapa atual?

**Grão:** pedido.

```text
stage_aging_hours =
analysis_at - current_stage_started_at
```

Faixas iniciais:

| Faixa | Intervalo |
|---|---|
| Até 12 horas | `< 12h` |
| De 12 a 24 horas | `>= 12h e < 24h` |
| De 24 a 48 horas | `>= 24h e < 48h` |
| De 48 a 72 horas | `>= 48h e < 72h` |
| Acima de 72 horas | `>= 72h` |

Essas faixas são analíticas e não substituem a política de SLA.

## Lead time de pagamento

```text
payment_lead_time_hours =
payment_approved_at - created_at
```

Elegível quando os dois timestamps forem válidos.

## Lead time de alocação

```text
allocation_lead_time_hours =
allocated_at - payment_approved_at
```

## Lead time de picking

```text
picking_lead_time_hours =
picking_completed_at - picking_started_at
```

## Lead time de packing

```text
packing_lead_time_hours =
packed_at - picking_completed_at
```

## Lead time de expedição

```text
dispatch_lead_time_hours =
shipped_at - packed_at
```

## Lead time de transporte

```text
transport_lead_time_hours =
delivered_at - shipped_at
```

## Lead time total

**Pergunta:** quanto tempo decorreu entre a criação e a entrega?

```text
total_lead_time_hours =
delivered_at - created_at
```

**Elegibilidade:**

- pedido entregue;
- timestamps válidos;
- pedido não cancelado.

## Mediana

A mediana representa o valor central das observações ordenadas.

Ela será a medida principal para representar o comportamento típico dos tempos, pois sofre menos influência de valores extremos do que a média.

## Percentil 90

O P90 representa o tempo abaixo do qual estão 90% das observações elegíveis.

Ele será utilizado para identificar a cauda do processo e revelar situações que a média ou a mediana podem ocultar.

Toda apresentação de P90 deverá informar também a quantidade de observações.

## Política de SLA

As políticas serão versionadas e poderão conter:

- etapa;
- centro de distribuição;
- região;
- nível de serviço;
- limite em horas;
- início da vigência;
- fim da vigência.

A política aplicável será determinada na entrada do pedido em cada etapa.

Quando mais de uma política puder ser aplicada, terá prioridade a regra mais específica.

Exemplo de prioridade:

1. etapa, centro, região e nível de serviço;
2. etapa, centro e nível de serviço;
3. etapa e nível de serviço;
4. regra padrão da etapa.

Pedidos sem política aplicável serão sinalizados como `no_policy` e não entrarão no denominador da conformidade de SLA.

## SLA da etapa concluída

**Pergunta:** qual percentual das etapas concluídas respeitou o limite definido?

Uma etapa será considerada dentro do SLA quando:

```text
stage_duration_hours <= threshold_hours
```

**Fórmula:**

```text
etapas concluídas dentro do SLA
÷
etapas concluídas elegíveis
```

## Violação de SLA em aberto

**Pergunta:** quantos pedidos atualmente em processamento já excederam o limite da etapa?

Um pedido estará em violação quando:

```text
stage_aging_hours > threshold_hours
```

**Fórmula:**

```text
pedidos abertos acima do SLA
÷
pedidos abertos com política aplicável
```

Essa métrica será separada da conformidade histórica das etapas concluídas.

## Próximo do vencimento do SLA

Um pedido será considerado próximo do vencimento quando tiver consumido pelo menos 80% do limite aplicável:

```text
stage_aging_hours >= threshold_hours * 0.80
e
stage_aging_hours <= threshold_hours
```

O percentual de 80% será inicialmente configurável.

## On-time

**Pergunta:** o pedido foi entregue até o prazo prometido?

```text
is_on_time =
delivered_at <= promised_delivery_at
```

Pedidos não entregues após a data prometida serão considerados atrasados em aberto.

## In-full

**Pergunta:** o pedido foi entregue integralmente?

```text
is_in_full =
delivered_quantity = eligible_ordered_quantity
```

O cálculo será realizado por item antes da consolidação do pedido.

Um pedido somente será `in_full` quando todos os itens elegíveis tiverem sido entregues integralmente.

## OTIF

**Nome:** On Time In Full.

**Pergunta:** qual percentual dos pedidos foi atendido integralmente e dentro do prazo?

Um pedido será aprovado no OTIF quando:

```text
is_on_time = true
e
is_in_full = true
```

### População elegível

Entram no denominador:

- pedidos cuja data prometida já venceu ou ocorreu no período analisado;
- pedidos não cancelados;
- pedidos com data prometida válida.

Pedidos vencidos e ainda não entregues entram como falha. Isso impede que pedidos em atraso sejam omitidos da métrica.

### Fórmula

```text
pedidos elegíveis on-time e in-full
÷
total de pedidos elegíveis
```

**Data de referência:** `promised_delivery_at`.

## Taxa de entrega no prazo

```text
pedidos elegíveis on-time
÷
pedidos elegíveis
```

Essa métrica considera apenas o prazo e não exige entrega completa.

## Fill rate

**Pergunta:** qual percentual das unidades pedidas foi entregue?

```text
soma das unidades entregues
÷
soma das unidades pedidas elegíveis
```

O fill rate é uma métrica de quantidade e não deve ser confundido com o `in_full`, calculado no nível do pedido.

## Taxa de entrega parcial

```text
pedidos entregues parcialmente
÷
pedidos entregues elegíveis
```

Um pedido é parcial quando:

```text
0 < delivered_quantity < ordered_quantity
```

## Taxa de cancelamento

```text
pedidos cancelados
÷
pedidos criados
```

A análise utilizará `created_at` como referência temporal para numerador e denominador.

## Pedidos em risco

**Pergunta:** quantos pedidos abertos apresentam sinais que exigem atenção?

Um pedido será considerado em risco quando possuir pelo menos um sinal ativo.

Exemplos:

- SLA da etapa excedido;
- consumo de pelo menos 80% do SLA;
- prazo prometido próximo;
- pedido vencido e ainda não entregue;
- evento obrigatório ausente;
- ausência de atualização de transporte.

**Fórmula:**

```text
count(distinct order_id com sinal de risco ativo)
```

## Taxa de pedidos em risco

```text
pedidos abertos em risco
÷
pedidos presentes no backlog
```

## Severidade do risco

A severidade inicial será definida por regras:

| Severidade | Exemplo |
|---|---|
| Alta | Prazo prometido vencido ou SLA muito excedido |
| Média | Próximo do prazo ou SLA recém-excedido |
| Baixa | Sinal preventivo sem violação atual |

A fila deverá preservar todos os sinais, mas apresentar uma única severidade consolidada por pedido.

## Modelos de referência planejados

| Grupo | Modelo |
|---|---|
| Jornada | `fct_order_lifecycle` |
| Pedidos | `fct_order` |
| Itens | `fct_order_item` |
| Eventos | `fct_order_event` |
| Entregas | `fct_shipment` |
| Fluxo | `mart_order_cycle` |
| Etapas | `mart_stage_performance` |
| Controle operacional | `mart_control_tower` |
| Pedidos em risco | `mart_orders_at_risk` |
| OTIF | `mart_delivery_otif` |

Os nomes poderão ser ajustados durante a modelagem, desde que a alteração seja documentada.

## Regras de apresentação

- Percentuais serão apresentados com uma casa decimal.
- Horas poderão ser apresentadas com uma casa decimal.
- Quantidades utilizarão números inteiros.
- Métricas deverão informar o período analisado.
- Comparações deverão utilizar períodos equivalentes.
- Resultados com poucas observações deverão apresentar o volume da amostra.
- Valores ausentes não serão convertidos automaticamente em zero.