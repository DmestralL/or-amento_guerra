alter table public.transactions
 add column if not exists credit_card_id uuid references public.credit_cards(id) on delete set null,
 add column if not exists credit_card_invoice_id uuid references public.credit_card_invoices(id) on delete set null;

create index if not exists transactions_credit_card_idx
 on public.transactions(credit_card_id, occurred_on desc)
 where credit_card_id is not null;

create index if not exists transactions_credit_card_invoice_idx
 on public.transactions(credit_card_invoice_id)
 where credit_card_invoice_id is not null;
