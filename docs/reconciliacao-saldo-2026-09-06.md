# Reconciliação de saldo — 06/09/2026

## Divergência identificada

- Saldo em contas exibido no app: R$ 7.885,26
- Protegido: R$ 4.591,84
- Disponível real exibido: R$ 3.293,42
- Disponível real conferido manualmente: R$ 3.099,60
- Divergência: R$ 193,82

## Saldo esperado

Se o protegido de R$ 4.591,84 está correto, então o saldo em contas deveria ser:

R$ 3.099,60 + R$ 4.591,84 = R$ 7.691,44

Logo, existe R$ 193,82 a mais no saldo em contas do app.

## Hipóteses a verificar no histórico

1. Saldo inicial lançado R$ 193,82 acima do real.
2. Receita/entrada duplicada no valor de R$ 193,82 ou soma equivalente.
3. Despesa de R$ 193,82 ausente do histórico.
4. Transferência entre contas tratada como receita em uma ponta sem a saída correspondente.
5. Ajuste manual de conta sem contrapartida.
6. Movimentação antiga migrada/importada incorretamente.

## Regra de reconciliação

Não corrigir o campo `disponível real` manualmente. O disponível real deve continuar derivado de:

`saldo em contas - valores protegidos`

A correção deve ocorrer na conta ou movimentação que produz os R$ 193,82 excedentes.

## Procedimento recomendado no app

Adicionar uma tela/rotina de reconciliação que mostre, por conta:

- saldo inicial;
- entradas confirmadas;
- saídas confirmadas;
- transferências recebidas;
- transferências enviadas;
- saldo calculado;
- saldo informado pelo banco;
- divergência.

Fórmula:

`saldo calculado = saldo inicial + receitas + transferências recebidas - despesas - transferências enviadas`

A soma dos saldos calculados das contas deve bater com o saldo em contas exibido no dashboard.

## Meta desta reconciliação

Encontrar a origem exata dos R$ 193,82 antes de qualquer ajuste manual de saldo.
