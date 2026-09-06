alter table public.transactions add column if not exists affects_cash boolean, add column if not exists affects_budget boolean;
update public.transactions set affects_cash=case when type='income' then true when type='transfer' or credit_card_id is not null then false else true end where affects_cash is null;
update public.transactions set affects_budget=case when type in ('expense','debt_payment') then true else false end where affects_budget is null;
alter table public.transactions alter column affects_cash set not null, alter column affects_cash set default true, alter column affects_budget set not null, alter column affects_budget set default true;

create table if not exists public.protected_funds(
 id uuid primary key default gen_random_uuid(), household_id uuid not null references public.households(id) on delete cascade,
 name text not null, amount numeric(14,2) not null check(amount>=0), protected_until date, active boolean not null default true,
 value_status public.value_status not null default 'confirmed', created_by uuid references auth.users(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(household_id,name)
);
create index if not exists protected_funds_household_active_idx on public.protected_funds(household_id) where active;
alter table public.protected_funds enable row level security;
revoke all on public.protected_funds from anon,authenticated;
grant select,insert,update,delete on public.protected_funds to authenticated;
create policy protected_funds_select on public.protected_funds for select to authenticated using(household_id in(select private.user_household_ids()));
create policy protected_funds_insert on public.protected_funds for insert to authenticated with check(household_id in(select private.user_household_ids()));
create policy protected_funds_update on public.protected_funds for update to authenticated using(household_id in(select private.user_household_ids())) with check(household_id in(select private.user_household_ids()));
create policy protected_funds_delete on public.protected_funds for delete to authenticated using(household_id in(select private.user_household_ids()));

alter table public.financial_events add column if not exists affects_budget boolean not null default false, add column if not exists external_key text;
create unique index if not exists financial_events_household_external_key_uidx on public.financial_events(household_id,external_key) where external_key is not null;

create or replace function public.complete_financial_event(target_event_id uuid,actual_amount numeric default null,completed_on date default current_date) returns uuid language plpgsql security invoker set search_path=''
as $$ declare item public.financial_events%rowtype; category_id uuid; new_transaction_id uuid; begin
 select * into item from public.financial_events where id=target_event_id for update;
 if not found then raise exception 'Evento não encontrado ou sem acesso'; end if;
 if item.status<>'planned' then raise exception 'Este evento já foi finalizado'; end if;
 if coalesce(actual_amount,item.amount,0)>0 and item.event_type in ('bill_due','expense') then
  select id into category_id from public.transaction_categories where household_id=item.household_id and kind='expense' order by case when name='Outros' then 0 else 1 end limit 1;
  insert into public.transactions(household_id,type,amount,category_id,description,occurred_on,planned,affects_cash,affects_budget,created_by,metadata)
  values(item.household_id,'expense',coalesce(actual_amount,item.amount),category_id,item.title,completed_on,true,true,item.affects_budget,(select auth.uid()),jsonb_build_object('financial_event_id',item.id,'registered_by','Calendário')) returning id into new_transaction_id;
 end if;
 update public.financial_events set status=case when new_transaction_id is null then 'completed' else 'paid' end,amount=coalesce(actual_amount,amount),transaction_id=new_transaction_id,updated_at=now() where id=item.id;
 return new_transaction_id; end $$;

insert into public.protected_funds(household_id,name,amount,protected_until,created_by)
select h.id,'Salário de Outubro',3300,date '2026-10-01',h.created_by from public.households h on conflict(household_id,name) do update set amount=excluded.amount,protected_until=excluded.protected_until,active=true,updated_at=now();
insert into public.protected_funds(household_id,name,amount,created_by)
select h.id,'Reserva mínima',1291.84,h.created_by from public.households h on conflict(household_id,name) do update set amount=excluded.amount,active=true,updated_at=now();

update public.financial_events set amount=479.58,external_key='nubank-2026-09',metadata=metadata||'{"closing_on":"2026-09-17"}'::jsonb,affects_budget=false where title='Vencimento Nubank' and starts_on=date '2026-09-22';
insert into public.financial_events(household_id,title,starts_on,amount,event_type,affects_budget,external_key) select id,'Apartamento',date '2026-09-20',433.02,'bill_due',true,'apartamento-2026-09' from public.households on conflict(household_id,external_key) where external_key is not null do update set amount=excluded.amount;
insert into public.financial_events(household_id,title,starts_on,amount,event_type,affects_budget,external_key) select id,'Santander',date '2026-09-20',104,'bill_due',true,'santander-2026-09' from public.households on conflict(household_id,external_key) where external_key is not null do update set amount=excluded.amount;
insert into public.financial_events(household_id,title,starts_on,amount,event_type,affects_budget,external_key) select id,'Tenda',date '2026-10-10',1102.06,'bill_due',false,'tenda-2026-10' from public.households on conflict(household_id,external_key) where external_key is not null do update set amount=excluded.amount;
insert into public.planned_income(household_id,description,amount,expected_on,income_class,status,value_status) select h.id,'Adiantamento (valor a confirmar)',null,date '2026-10-20','variable','planned','to_confirm' from public.households h where not exists(select 1 from public.planned_income p where p.household_id=h.id and p.description='Adiantamento (valor a confirmar)' and p.expected_on=date '2026-10-20');

do $$ begin if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='protected_funds') then alter publication supabase_realtime add table public.protected_funds; end if; end $$;
alter table public.protected_funds replica identity full;
