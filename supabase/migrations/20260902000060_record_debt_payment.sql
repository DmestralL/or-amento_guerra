create or replace function public.record_debt_payment(
 target_debt_id uuid,
 payment_amount numeric,
 payment_date date,
 payment_description text default null
) returns uuid
language plpgsql
security invoker
set search_path=''
as $$
declare selected_debt public.debts%rowtype; category_id uuid; transaction_id uuid;
begin
 if payment_amount <= 0 then raise exception 'O pagamento deve ser maior que zero'; end if;
 select * into selected_debt from public.debts where id=target_debt_id;
 if not found then raise exception 'Dívida não encontrada ou sem acesso'; end if;
 select id into category_id from public.transaction_categories
  where household_id=selected_debt.household_id and name='Dívidas' and kind='expense' limit 1;
 insert into public.transactions(household_id,type,amount,category_id,description,occurred_on,planned,created_by,metadata)
 values(selected_debt.household_id,'debt_payment',payment_amount,category_id,coalesce(nullif(payment_description,''),'Pagamento - '||selected_debt.creditor),payment_date,true,(select auth.uid()),jsonb_build_object('debt_id',target_debt_id,'registered_by','Família'))
 returning id into transaction_id;
 insert into public.debt_payments(household_id,debt_id,transaction_id,amount,paid_on,created_by)
 values(selected_debt.household_id,target_debt_id,transaction_id,payment_amount,payment_date,(select auth.uid()));
 update public.debts set
  balance=case when balance is null then null else greatest(balance-payment_amount,0) end,
  current_installment=case when current_installment is null then null else least(current_installment+1,coalesce(total_installments,current_installment+1)) end,
  status=case when balance is not null and balance-payment_amount<=0 then 'Quitada' else status end,
  last_updated_at=now(),updated_at=now()
 where id=target_debt_id;
 return transaction_id;
end $$;

revoke all on function public.record_debt_payment(uuid,numeric,date,text) from public,anon;
grant execute on function public.record_debt_payment(uuid,numeric,date,text) to authenticated;
