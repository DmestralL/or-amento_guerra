delete from public.financial_events
where id = '05b83da4-90ea-49b5-a764-17d0c3db5d70'
  and lower(btrim(title)) = 'tenda'
  and status = 'paid'
  and transaction_id = '5ce7e7d5-24e5-4db5-bed8-953eb8c03cbe';

delete from public.transactions
where id = '5ce7e7d5-24e5-4db5-bed8-953eb8c03cbe'
  and lower(btrim(description)) = 'tenda'
  and amount = 1102.06
  and occurred_on = date '2026-09-06'
  and credit_card_id is null
  and metadata ->> 'registered_by' = 'Calendário';
