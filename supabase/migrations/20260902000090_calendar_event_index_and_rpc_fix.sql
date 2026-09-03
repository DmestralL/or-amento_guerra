create index if not exists financial_events_transaction_idx on public.financial_events(transaction_id);

create or replace function public.complete_financial_event(
 target_event_id uuid, actual_amount numeric default null, completed_on date default current_date
) returns uuid language plpgsql security invoker set search_path=''
as $$
declare item public.financial_events%rowtype; category_id uuid; created_transaction_id uuid;
begin
 select * into item from public.financial_events where id=target_event_id for update;
 if not found then raise exception 'Evento não encontrado ou sem acesso'; end if;
 if item.status<>'planned' then raise exception 'Este evento já foi finalizado'; end if;
 if coalesce(actual_amount,item.amount,0)>0 and item.event_type in ('bill_due','expense') then
  select id into category_id from public.transaction_categories where household_id=item.household_id and kind='expense' order by case when name='Outros' then 0 else 1 end limit 1;
  insert into public.transactions(household_id,type,amount,category_id,description,occurred_on,planned,created_by,metadata)
  values(item.household_id,'expense',coalesce(actual_amount,item.amount),category_id,item.title,completed_on,true,(select auth.uid()),jsonb_build_object('financial_event_id',item.id,'registered_by','Calendário')) returning id into created_transaction_id;
 end if;
 update public.financial_events set status=case when created_transaction_id is null then 'completed' else 'paid' end,
  amount=coalesce(actual_amount,amount),transaction_id=created_transaction_id,updated_at=now() where id=item.id;
 return created_transaction_id;
end $$;

revoke all on function public.complete_financial_event(uuid,numeric,date) from public,anon;
grant execute on function public.complete_financial_event(uuid,numeric,date) to authenticated;
