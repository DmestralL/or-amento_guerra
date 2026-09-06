-- A compra Tenda já consome o orçamento de supermercado, mas o dinheiro
-- só sai da conta quando a obrigação de 10/10 for paga.
update public.transactions
set amount = 1102.06,
    affects_cash = false,
    affects_budget = true,
    metadata = metadata || jsonb_build_object('external_key', 'tenda-supermercado-2026-09'),
    updated_at = now()
where id = (
  select id
  from public.transactions
  where lower(btrim(description)) = 'tenda'
    and occurred_on between date '2026-09-01' and date '2026-09-30'
  order by created_at
  limit 1
);
