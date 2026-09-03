alter table public.financial_events
 add column if not exists status text not null default 'planned',
 add column if not exists transaction_id uuid references public.transactions(id);

alter table public.financial_events drop constraint if exists financial_events_status_check;
alter table public.financial_events add constraint financial_events_status_check
 check (status in ('planned','completed','paid','cancelled'));

create index if not exists recurring_transactions_household_date_idx
 on public.recurring_transactions(household_id,next_date) where active;

create or replace function public.receive_planned_income(
 target_income_id uuid, received_amount numeric, received_on date
) returns uuid language plpgsql security invoker set search_path=''
as $$
declare item public.planned_income%rowtype; category_id uuid; transaction_id uuid;
begin
 if received_amount <= 0 then raise exception 'O valor recebido deve ser maior que zero'; end if;
 select * into item from public.planned_income where id=target_income_id for update;
 if not found then raise exception 'Receita não encontrada ou sem acesso'; end if;
 if item.status='received' then raise exception 'Esta receita já foi recebida'; end if;
 select id into category_id from public.transaction_categories
  where household_id=item.household_id and kind='income'
  order by case when name='Renda extra' then 0 else 1 end limit 1;
 if category_id is null then
  insert into public.transaction_categories(household_id,name,kind)
  values(item.household_id,'Renda extra','income') returning id into category_id;
 end if;
 insert into public.transactions(household_id,type,amount,category_id,description,occurred_on,planned,is_extraordinary,created_by,metadata)
 values(item.household_id,'income',received_amount,category_id,item.description,received_on,true,item.income_class='extraordinary',(select auth.uid()),jsonb_build_object('planned_income_id',item.id,'registered_by','Calendário'))
 returning id into transaction_id;
 update public.planned_income set status='received',amount=received_amount,value_status='confirmed',received_transaction_id=transaction_id,updated_at=now() where id=item.id;
 return transaction_id;
end $$;

create or replace function public.pay_recurring_transaction(
 target_recurring_id uuid, paid_amount numeric, paid_on date
) returns uuid language plpgsql security invoker set search_path=''
as $$
declare item public.recurring_transactions%rowtype; transaction_id uuid; following_date date;
begin
 if paid_amount <= 0 then raise exception 'O valor pago deve ser maior que zero'; end if;
 select * into item from public.recurring_transactions where id=target_recurring_id and active for update;
 if not found then raise exception 'Recorrência não encontrada, inativa ou sem acesso'; end if;
 insert into public.transactions(household_id,type,amount,category_id,description,occurred_on,planned,created_by,metadata)
 values(item.household_id,item.type,paid_amount,item.category_id,item.description,paid_on,true,(select auth.uid()),jsonb_build_object('recurring_transaction_id',item.id,'scheduled_for',item.next_date,'registered_by','Calendário'))
 returning id into transaction_id;
 following_date := case item.frequency
  when 'weekly' then item.next_date+7
  when 'biweekly' then item.next_date+14
  when 'yearly' then (item.next_date+interval '1 year')::date
  else (item.next_date+interval '1 month')::date end;
 update public.recurring_transactions set next_date=following_date,
  active=not (ends_on is not null and following_date>ends_on),updated_at=now() where id=item.id;
 return transaction_id;
end $$;

create or replace function public.complete_financial_event(
 target_event_id uuid, actual_amount numeric default null, completed_on date default current_date
) returns uuid language plpgsql security invoker set search_path=''
as $$
declare item public.financial_events%rowtype; category_id uuid; transaction_id uuid;
begin
 select * into item from public.financial_events where id=target_event_id for update;
 if not found then raise exception 'Evento não encontrado ou sem acesso'; end if;
 if item.status<>'planned' then raise exception 'Este evento já foi finalizado'; end if;
 if coalesce(actual_amount,item.amount,0)>0 and item.event_type in ('bill_due','expense') then
  select id into category_id from public.transaction_categories where household_id=item.household_id and kind='expense' order by case when name='Outros' then 0 else 1 end limit 1;
  insert into public.transactions(household_id,type,amount,category_id,description,occurred_on,planned,created_by,metadata)
  values(item.household_id,'expense',coalesce(actual_amount,item.amount),category_id,item.title,completed_on,true,(select auth.uid()),jsonb_build_object('financial_event_id',item.id,'registered_by','Calendário')) returning id into transaction_id;
 end if;
 update public.financial_events set status=case when transaction_id is null then 'completed' else 'paid' end,
  amount=coalesce(actual_amount,amount),transaction_id=transaction_id,updated_at=now() where id=item.id;
 return transaction_id;
end $$;

revoke all on function public.receive_planned_income(uuid,numeric,date) from public,anon;
revoke all on function public.pay_recurring_transaction(uuid,numeric,date) from public,anon;
revoke all on function public.complete_financial_event(uuid,numeric,date) from public,anon;
grant execute on function public.receive_planned_income(uuid,numeric,date) to authenticated;
grant execute on function public.pay_recurring_transaction(uuid,numeric,date) to authenticated;
grant execute on function public.complete_financial_event(uuid,numeric,date) to authenticated;

do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='planned_income') then alter publication supabase_realtime add table public.planned_income; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='financial_events') then alter publication supabase_realtime add table public.financial_events; end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='recurring_transactions') then alter publication supabase_realtime add table public.recurring_transactions; end if;
end $$;

alter table public.planned_income replica identity full;
alter table public.financial_events replica identity full;
alter table public.recurring_transactions replica identity full;

insert into public.planned_income(household_id,description,amount,expected_on,income_class,status,value_status)
select h.id,'Aluguel a receber',867.18,date '2026-09-25','variable','planned','confirmed'
from public.households h where not exists(select 1 from public.planned_income p where p.household_id=h.id and p.description='Aluguel a receber');
insert into public.financial_events(household_id,title,starts_on,ends_on,amount,event_type,metadata)
select h.id,'Congresso',date '2026-09-10',date '2026-09-13',1600,'project','{"separate_budget":true}'::jsonb from public.households h
where not exists(select 1 from public.financial_events e where e.household_id=h.id and e.title='Congresso' and e.starts_on=date '2026-09-10');
insert into public.financial_events(household_id,title,starts_on,amount,event_type)
select h.id,'Vencimento Nubank',date '2026-09-22',422.68,'bill_due' from public.households h
where not exists(select 1 from public.financial_events e where e.household_id=h.id and e.title='Vencimento Nubank' and e.starts_on=date '2026-09-22');
insert into public.recurring_transactions(household_id,type,description,amount,frequency,next_date,ends_on)
select h.id,'expense','Energia / sistema solar',310,'monthly',date '2026-09-05',date '2027-11-30' from public.households h
where not exists(select 1 from public.recurring_transactions r where r.household_id=h.id and r.description='Energia / sistema solar');
