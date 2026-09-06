alter table public.transactions
 add column if not exists installment_group_id uuid,
 add column if not exists installment_number integer,
 add column if not exists installment_total integer;

alter table public.transactions drop constraint if exists transactions_installment_numbers_check;
alter table public.transactions add constraint transactions_installment_numbers_check check (
 (installment_group_id is null and installment_number is null and installment_total is null)
 or (installment_group_id is not null and installment_number between 1 and installment_total and installment_total between 1 and 120)
);

create unique index if not exists transactions_installment_unique_idx
 on public.transactions(installment_group_id,installment_number) where installment_group_id is not null;
create unique index if not exists transactions_import_key_unique_idx
 on public.transactions(household_id,(metadata->>'import_key')) where metadata ? 'import_key';

alter table public.recurring_transactions
 add column if not exists credit_card_id uuid references public.credit_cards(id) on delete set null;
create index if not exists recurring_transactions_credit_card_idx on public.recurring_transactions(credit_card_id) where credit_card_id is not null;

create or replace function public.register_credit_card_purchase(
 target_card_id uuid,
 purchase_description text,
 installment_amount numeric,
 purchase_date date,
 installment_count integer default 1,
 make_recurring boolean default false,
 request_group_id uuid default gen_random_uuid()
) returns uuid[] language plpgsql security invoker set search_path=''
as $$
declare selected_card public.credit_cards%rowtype; category_id uuid; created_ids uuid[] := '{}'; created_id uuid; part integer;
begin
 if nullif(trim(purchase_description),'') is null then raise exception 'Informe a descrição da compra'; end if;
 if installment_amount<=0 then raise exception 'O valor deve ser maior que zero'; end if;
 if installment_count not between 1 and 120 then raise exception 'Quantidade de parcelas inválida'; end if;
 if make_recurring and installment_count>1 then raise exception 'Uma compra não pode ser parcelada e recorrente ao mesmo tempo'; end if;
 select * into selected_card from public.credit_cards where id=target_card_id and active;
 if not found then raise exception 'Cartão não encontrado, inativo ou sem acesso'; end if;
 select id into category_id from public.transaction_categories where household_id=selected_card.household_id and name='Assinaturas e cartão' and kind='expense';
 if category_id is null then
  insert into public.transaction_categories(household_id,name,kind) values(selected_card.household_id,'Assinaturas e cartão','expense')
  on conflict(household_id,name,kind) do update set active=true returning id into category_id;
 end if;
 for part in 1..installment_count loop
  insert into public.transactions(id,household_id,type,amount,category_id,credit_card_id,description,occurred_on,planned,created_by,installment_group_id,installment_number,installment_total,metadata)
  values(gen_random_uuid(),selected_card.household_id,'expense',installment_amount,category_id,target_card_id,trim(purchase_description)||case when installment_count>1 then ' ('||part||'/'||installment_count||')' else '' end,(purchase_date+(part-1)*interval '1 month')::date,true,(select auth.uid()),request_group_id,part,installment_count,jsonb_build_object('registered_by','Compra no cartão','installment_group_id',request_group_id))
  on conflict(installment_group_id,installment_number) where installment_group_id is not null do update set updated_at=public.transactions.updated_at
  returning id into created_id;
  created_ids:=array_append(created_ids,created_id);
 end loop;
 if make_recurring and not exists(select 1 from public.recurring_transactions where household_id=selected_card.household_id and credit_card_id=target_card_id and lower(description)=lower(trim(purchase_description)) and active) then
  insert into public.recurring_transactions(household_id,type,description,amount,category_id,credit_card_id,frequency,next_date,active)
  values(selected_card.household_id,'expense',trim(purchase_description),installment_amount,category_id,target_card_id,'monthly',(purchase_date+interval '1 month')::date,true);
 end if;
 return created_ids;
end $$;

revoke all on function public.register_credit_card_purchase(uuid,text,numeric,date,integer,boolean,uuid) from public,anon;
grant execute on function public.register_credit_card_purchase(uuid,text,numeric,date,integer,boolean,uuid) to authenticated;

create or replace function public.pay_recurring_transaction(
 target_recurring_id uuid, paid_amount numeric, paid_on date
) returns uuid language plpgsql security invoker set search_path=''
as $$
declare item public.recurring_transactions%rowtype; transaction_id uuid; following_date date;
begin
 if paid_amount <= 0 then raise exception 'O valor pago deve ser maior que zero'; end if;
 select * into item from public.recurring_transactions where id=target_recurring_id and active for update;
 if not found then raise exception 'Recorrência não encontrada, inativa ou sem acesso'; end if;
 insert into public.transactions(household_id,type,amount,category_id,credit_card_id,description,occurred_on,planned,created_by,metadata)
 values(item.household_id,item.type,paid_amount,item.category_id,item.credit_card_id,item.description,paid_on,true,(select auth.uid()),jsonb_build_object('recurring_transaction_id',item.id,'scheduled_for',item.next_date,'registered_by','Calendário'))
 returning id into transaction_id;
 following_date := case item.frequency when 'weekly' then item.next_date+7 when 'biweekly' then item.next_date+14 when 'yearly' then (item.next_date+interval '1 year')::date else (item.next_date+interval '1 month')::date end;
 update public.recurring_transactions set next_date=following_date,active=not (ends_on is not null and following_date>ends_on),updated_at=now() where id=item.id;
 return transaction_id;
end $$;

revoke all on function public.pay_recurring_transaction(uuid,numeric,date) from public,anon;
grant execute on function public.pay_recurring_transaction(uuid,numeric,date) to authenticated;

insert into public.transaction_categories(household_id,name,kind)
select h.id,'Assinaturas e cartão','expense' from public.households h on conflict(household_id,name,kind) do update set active=true;

with base as (
 select h.id household_id,h.created_by,c.id card_id,tc.id category_id from public.households h join public.credit_cards c on c.household_id=h.id and lower(c.name)='nubank' join public.transaction_categories tc on tc.household_id=h.id and tc.name='Assinaturas e cartão' and tc.kind='expense'
), items(description,amount,purchase_date,import_key) as (values
 ('Shopfy',106.36,date '2026-09-06','nubank-2026-09-shopfy'),('TotalPass',89.90,date '2026-09-06','nubank-2026-09-totalpass'),('Casale',26.99,date '2026-09-06','nubank-2026-09-casale'),('Google One',9.90,date '2026-09-06','nubank-2026-09-google-one'),('PSN',4.33,date '2026-09-06','nubank-2026-09-psn'),('Amazon',19.90,date '2026-09-16','nubank-2026-09-amazon')
)
insert into public.transactions(household_id,type,amount,category_id,credit_card_id,description,occurred_on,planned,created_by,installment_group_id,installment_number,installment_total,metadata)
select b.household_id,'expense',i.amount,b.category_id,b.card_id,i.description,i.purchase_date,true,b.created_by,gen_random_uuid(),1,1,jsonb_build_object('registered_by','Importação Nubank','import_key',i.import_key)
from base b cross join items i on conflict do nothing;

with base as (
 select h.id household_id,h.created_by,c.id card_id,tc.id category_id from public.households h join public.credit_cards c on c.household_id=h.id and lower(c.name)='nubank' join public.transaction_categories tc on tc.household_id=h.id and tc.name='Assinaturas e cartão' and tc.kind='expense'
), plans(description,amount,total_parts,group_id,import_prefix) as (values
 ('Cartão PSN',47.00,6,'927b35c2-2076-4d8a-a326-e43af31f3c2a'::uuid,'nubank-cartao-psn'),('Droga Raia',64.60,2,'37ec9aa6-b88e-4bb0-bb0f-6c80aca256bd'::uuid,'nubank-droga-raia')
)
insert into public.transactions(household_id,type,amount,category_id,credit_card_id,description,occurred_on,planned,created_by,installment_group_id,installment_number,installment_total,metadata)
select b.household_id,'expense',p.amount,b.category_id,b.card_id,p.description||' ('||n||'/'||p.total_parts||')',(date '2026-09-06'+(n-1)*interval '1 month')::date,true,b.created_by,p.group_id,n,p.total_parts,jsonb_build_object('registered_by','Importação Nubank','import_key',p.import_prefix||'-'||n)
from base b cross join plans p cross join lateral generate_series(1,p.total_parts) n on conflict do nothing;

with base as (select h.id household_id,c.id card_id,tc.id category_id from public.households h join public.credit_cards c on c.household_id=h.id and lower(c.name)='nubank' join public.transaction_categories tc on tc.household_id=h.id and tc.name='Assinaturas e cartão' and tc.kind='expense'), recurring(description,amount,next_date) as (values ('Meli+',9.90,date '2026-09-30'),('TotalPass',89.90,date '2026-10-06'),('Google One',9.90,date '2026-10-06'),('Amazon',19.90,date '2026-10-16'))
insert into public.recurring_transactions(household_id,type,description,amount,category_id,credit_card_id,frequency,next_date,active)
select b.household_id,'expense',r.description,r.amount,b.category_id,b.card_id,'monthly',r.next_date,true from base b cross join recurring r
where not exists(select 1 from public.recurring_transactions x where x.household_id=b.household_id and x.credit_card_id=b.card_id and lower(x.description)=lower(r.description) and x.active);
