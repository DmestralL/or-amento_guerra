alter table public.protected_funds
  add column if not exists source_account_id uuid references public.accounts(id) on delete set null,
  add column if not exists included_in_account_balance boolean not null default false;
create index if not exists protected_funds_source_account_idx on public.protected_funds(source_account_id);

create table public.account_reconciliations (id uuid primary key default gen_random_uuid(),household_id uuid not null references public.households(id) on delete cascade,account_id uuid not null references public.accounts(id) on delete cascade,reported_balance numeric(14,2) not null,calculated_before numeric(14,2) not null,adjustment numeric(14,2) not null,external_key text,created_by uuid references auth.users(id),created_at timestamptz not null default now(),unique(household_id,external_key));
create index account_reconciliations_household_created_idx on public.account_reconciliations(household_id,created_at desc);
create index account_reconciliations_account_idx on public.account_reconciliations(account_id);
create index account_reconciliations_created_by_idx on public.account_reconciliations(created_by);
alter table public.account_reconciliations enable row level security;
revoke all on public.account_reconciliations from anon,authenticated;
grant select,insert on public.account_reconciliations to authenticated;
create policy account_reconciliations_select on public.account_reconciliations for select to authenticated using(household_id in(select private.user_household_ids()));
create policy account_reconciliations_insert on public.account_reconciliations for insert to authenticated with check(household_id in(select private.user_household_ids()) and created_by=(select auth.uid()));

create or replace function public.reconcile_account_balance(target_account_id uuid,reported_balance numeric) returns uuid language plpgsql security invoker set search_path=''
as $$ declare item public.accounts%rowtype; calculated numeric; adjustment_value numeric; reconciliation_id uuid; begin
 if reported_balance < 0 then raise exception 'O saldo informado não pode ser negativo'; end if;
 select * into item from public.accounts where id=target_account_id and available_for_spending for update;
 if not found then raise exception 'Conta não encontrada, indisponível ou sem acesso'; end if;
 select coalesce(sum(opening_balance),0)+(select coalesce(sum(case when type='income' and affects_cash then amount when type in ('expense','debt_payment') and affects_cash then -amount else 0 end),0) from public.transactions where household_id=item.household_id) into calculated from public.accounts where household_id=item.household_id and available_for_spending;
 adjustment_value:=reported_balance-calculated;
 update public.accounts set opening_balance=opening_balance+adjustment_value,updated_at=now() where id=item.id;
 insert into public.account_reconciliations(household_id,account_id,reported_balance,calculated_before,adjustment,created_by) values(item.household_id,item.id,reported_balance,calculated,adjustment_value,(select auth.uid())) returning id into reconciliation_id;
 return reconciliation_id; end $$;
revoke all on function public.reconcile_account_balance(uuid,numeric) from public,anon;
grant execute on function public.reconcile_account_balance(uuid,numeric) to authenticated;

update public.protected_funds p set name='Caixinha Turbo',amount=1284.76,included_in_account_balance=false,source_account_id=(select id from public.accounts a where a.household_id=p.household_id and a.available_for_spending order by a.created_at limit 1),updated_at=now() where p.name='Reserva mínima';
update public.protected_funds p set amount=3300,included_in_account_balance=false,source_account_id=(select id from public.accounts a where a.household_id=p.household_id and a.available_for_spending order by a.created_at limit 1),updated_at=now() where p.name='Salário de Outubro';
insert into public.protected_funds(household_id,name,amount,active,value_status,source_account_id,included_in_account_balance,created_by) select h.id,'Reserva de Emergência',10.92,true,'confirmed',a.id,false,h.created_by from public.households h join lateral(select id from public.accounts where household_id=h.id and available_for_spending order by created_at limit 1)a on true on conflict(household_id,name) do update set amount=excluded.amount,active=true,source_account_id=excluded.source_account_id,included_in_account_balance=false,updated_at=now();

with figures as (select a.household_id,min(a.id::text)::uuid account_id,coalesce(sum(a.opening_balance),0)+(select coalesce(sum(case when t.type='income' and t.affects_cash then t.amount when t.type in ('expense','debt_payment') and t.affects_cash then -t.amount else 0 end),0) from public.transactions t where t.household_id=a.household_id) calculated from public.accounts a where a.available_for_spending and not exists(select 1 from public.account_reconciliations r where r.household_id=a.household_id and r.external_key='nubank-photo-2026-09-06') group by a.household_id), adjusted as (update public.accounts a set opening_balance=a.opening_balance+(2821.60-f.calculated),updated_at=now() from figures f where a.id=f.account_id returning a.household_id,a.id account_id,f.calculated)
insert into public.account_reconciliations(household_id,account_id,reported_balance,calculated_before,adjustment,external_key) select household_id,account_id,2821.60,calculated,2821.60-calculated,'nubank-photo-2026-09-06' from adjusted on conflict(household_id,external_key) do nothing;
