# Correções de dados — 06/09/2026

Correções identificadas na conferência do CSV exportado do app com o controle financeiro real.

## Valores e categorias

- Tenda agosto pago: R$ 1.428,11 → categoria **Supermercado/Alimentação**.
- Compra Tenda atual: corrigir **R$ 544,12 para R$ 544,02** → categoria **Supermercado/Alimentação**.
- Tenda anterior: R$ 558,04 → categoria **Supermercado/Alimentação**.
- Fatura Tenda com vencimento 10/10: total correto **R$ 1.102,06**.
- Internet: corrigir **R$ 110,00 para R$ 109,00** → categoria **Internet**.
- TotalPass: R$ 89,90 → categoria **Academia**.
- Não usar "cartão", "Nubank" ou "Tenda" como categoria de despesa. Esses campos são forma de pagamento/conta/cartão; a categoria deve refletir a finalidade do gasto.

## Compromissos pendentes

- Nubank: R$ 479,58.
- Apartamento: R$ 433,02 — vencimento 20/09.
- Santander: R$ 104,00.
- Tenda: R$ 1.102,06 — vencimento 10/10.

## Valores protegidos

- Salário de outubro protegido: R$ 3.300,00.
- Reserva: R$ 1.291,84.
- Esses valores não são despesas e não devem reduzir patrimônio; apenas reduzem o disponível real.

## Receita prevista

- R$ 867,18 previstos para 25/09: não somar ao disponível enquanto não recebidos.
- Adiantamento de 20/10: valor ainda desconhecido; manter como previsto/a confirmar, sem somar ao saldo disponível.

## Shopify

- Despesa Shopify/"Shopfy" de R$ 106,36 foi identificada no CSV.
- Assinatura será cancelada pelo usuário.
- Após confirmação do cancelamento, não projetar essa cobrança como despesa recorrente futura.
- A cobrança já realizada continua sendo despesa do período em que ocorreu; cancelar não apaga o gasto já lançado.

## Regras de cálculo

1. Compra no cartão reduz o orçamento da categoria na data da compra.
2. Compra no cartão não reduz o caixa bancário na data da compra.
3. O caixa é reduzido quando a fatura é paga.
4. Pagamento da fatura não deve consumir o orçamento novamente.
5. Receita prevista não integra saldo disponível até ser marcada como recebida.
6. Valores protegidos reduzem o disponível real, mas não o saldo patrimonial.
