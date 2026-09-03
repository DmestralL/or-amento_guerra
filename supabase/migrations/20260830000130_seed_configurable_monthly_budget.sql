do $$
declare family_id uuid; v_budget_id uuid; item jsonb; v_category_id uuid;
begin
 select id into family_id from public.households where name='Família Fonseca' order by created_at limit 1;
 if family_id is null then raise exception 'Família não encontrada'; end if;
 insert into public.monthly_budgets(household_id,month,name,total_limit,separate_project)
 values(family_id,date '2026-09-01','Orçamento mensal',3226.58,false)
 on conflict(household_id,month,name) do update set total_limit=excluded.total_limit,updated_at=now()
 returning id into v_budget_id;
 for item in select * from jsonb_array_elements('[
  {"name":"Moradia","amount":435},{"name":"Energia","amount":310},{"name":"Gás","amount":60},
  {"name":"Internet","amount":110},{"name":"Celular","amount":35},{"name":"Supermercado","amount":1150},
  {"name":"Delivery/Lanches","amount":50},{"name":"Combustível","amount":200},{"name":"Crianças","amount":200},
  {"name":"Farmácia","amount":200},{"name":"Assinaturas","amount":40},{"name":"Academia","amount":90},
  {"name":"IPTU","amount":93},{"name":"Pet","amount":50},{"name":"Dívidas","amount":103.58},
  {"name":"Imprevistos","amount":100}
 ]'::jsonb)
 loop
  insert into public.transaction_categories(household_id,name,kind)
  values(family_id,item->>'name','expense')
  on conflict(household_id,name,kind) do update set active=true
  returning id into v_category_id;
  insert into public.budget_categories(household_id,budget_id,category_id,budgeted)
  values(family_id,v_budget_id,v_category_id,(item->>'amount')::numeric)
  on conflict(budget_id,category_id) do update set budgeted=excluded.budgeted,updated_at=now();
 end loop;
end $$;
