-- Execute depois da migration. Não cria usuário nem senha.
-- O usuário autenticado chama: select public.load_my_initial_data();
create or replace function public.load_my_initial_data() returns void language plpgsql security invoker set search_path='' as $$
declare h uuid; b uuid; c uuid;
begin
 select household_id into h from public.household_members where user_id=(select auth.uid()) and role='owner' limit 1;
 if h is null then raise exception 'Crie uma família antes de carregar os dados'; end if;
 update public.households set initial_seed_applied_at=now() where id=h and initial_seed_applied_at is null;
 if not found then raise exception 'Dados iniciais já carregados'; end if;
 insert into public.accounts(household_id,name,kind,opening_balance,available_for_spending,created_by) values
 (h,'Contas disponíveis','checking',650,true,auth.uid()),(h,'Reserva','reserve',1291.84,false,auth.uid()),(h,'Vale Alimentação','benefit',450,false,auth.uid());
 insert into public.assets(household_id,name,asset_type,value,value_status,available_for_spending,notes) values
 (h,'FGTS','fgts',2274.07,'confirmed',false,'Patrimônio; nunca somar ao saldo disponível'),(h,'Imóvel','real_estate',230000,'estimated',false,'Valor aproximado'),(h,'Saldo do financiamento','liability',146461.55,'confirmed',false,'309 meses restantes'),(h,'Renault Scenic 2007','vehicle',12000,'estimated',false,'Sem financiamento duplicado');
 insert into public.transaction_categories(household_id,name,kind) select h,x,'expense' from unnest(array['Moradia','Energia','Gás','Internet','Celular','Supermercado','Delivery/Lanches','Combustível','Crianças','Farmácia','Assinaturas','Academia','IPTU','Pet','Dívidas','Carro/Manutenção','Lazer','Imprevistos','Outros','Congresso Setembro']) x;
 insert into public.transaction_categories(household_id,name,kind) select h,x,'income' from unnest(array['Salário','Adiantamento','Horas extras','Férias','13º','Aluguel recebido','Renda extra','Outros']) x;
 insert into public.monthly_budgets(household_id,month,name,total_limit,created_by) values(h,'2026-09-01','Orçamento de Guerra',3226.58,auth.uid()) returning id into b;
 insert into public.budget_categories(household_id,budget_id,category_id,budgeted)
 select h,b,tc.id,v.amount from (values('Moradia',435::numeric),('Energia',310),('Gás',60),('Internet',110),('Celular',35),('Supermercado',1150),('Delivery/Lanches',50),('Combustível',200),('Crianças',200),('Farmácia',200),('Assinaturas',40),('Academia',90),('IPTU',93),('Pet',50),('Dívidas',103.58),('Imprevistos',100)) v(name,amount) join public.transaction_categories tc on tc.household_id=h and tc.name=v.name and tc.kind='expense';
 insert into public.monthly_budgets(household_id,month,name,total_limit,separate_project,created_by) values(h,'2026-09-01','Congresso Setembro',1600,true,auth.uid());
 insert into public.debts(household_id,creditor,debt_type,original_amount,balance,installment_amount,total_installments,current_installment,rate_reported,rate_notes,status,value_status,priority,notes) values
 (h,'Safra','Consignado CLT',15419.96,10229.92,950.80,24,12,3.21,'Periodicidade/CET a confirmar','Em dia','confirmed','Alto impacto','Pagamento de contas/dívidas'),
 (h,'Banco do Brasil','Consignado CLT',10295.67,8528.20,536.70,36,14,3.63,'Periodicidade a confirmar','Em dia','estimated','Alta','Compra do automóvel'),
 (h,'Santander','Acordo',4000,null,103.58,48,22,null,null,'Em dia','to_confirm','Média','Saldo de quitação desconhecido'),
 (h,'Banco do Brasil','Cartão/dívida antiga',6000,6000,null,null,null,null,null,'Inadimplente','estimated','Planejar','Mais de 1 ano'),
 (h,'Caixa','Dívida de consumo',5000,5000,null,null,null,null,null,'Inadimplente','estimated','Planejar','Mais de 1 ano'),
 (h,'Telhanorte','Dívida de consumo',null,4500,null,null,null,null,null,'Valor a confirmar','to_confirm','Confirmar','Valor informado era limite total; dívida efetiva a confirmar'),
 (h,'Mercado Pago','Cartão',5000,5000,null,null,null,null,null,'Inadimplente','estimated','Planejar','Mais de 6 meses');
 insert into public.credit_cards(household_id,name,credit_limit,closing_day,due_day) values(h,'Nubank',1600,17,22) returning id into c;
 insert into public.credit_card_invoices(household_id,card_id,closing_date,due_date,amount,status) values(h,c,'2026-09-17','2026-09-22',422.68,'open');
 insert into public.planned_income(household_id,description,amount,expected_on,income_class,status,value_status,notes) values
 (h,'Aluguel a receber',867.18,'2026-09-25','variable','planned','confirmed','Não soma ao saldo até recebimento'),
 (h,'Horas extras de agosto',null,null,'extraordinary','planned','to_confirm','18h16 registradas; atraso 15min; saldo 18h01; aguardando holerite'),
 (h,'1/3 de férias',null,null,'extraordinary','planned','to_confirm','Valor a confirmar. Não inventar valor.');
 insert into public.financial_events(household_id,title,starts_on,ends_on,amount,event_type,metadata) values
 (h,'Congresso','2026-09-10','2026-09-13',1600,'project','{"separate_budget":true}'),(h,'Fechamento Nubank','2026-09-17',null,422.68,'card_closing','{}'),(h,'Vencimento Nubank','2026-09-22',null,422.68,'bill_due','{}');
 insert into public.financial_goals(household_id,name,target_amount,current_amount,starts_on,ends_on) values(h,'Reserva inicial',3000,1291.84,'2026-09-01',null),(h,'Orçamento de Guerra — 90 dias',null,0,'2026-09-01','2026-11-29'),(h,'Fundo do carro',null,0,null,null);
 insert into public.recurring_transactions(household_id,type,description,amount,frequency,next_date,ends_on) values(h,'expense','Energia / sistema solar',310,'monthly','2026-09-01','2027-11-30');
 insert into public.financial_rules(household_id,label,sort_order) values(h,'Não criar nova dívida.',1),(h,'Não fazer compra parcelada porque apenas a parcela cabe.',2),(h,'Nenhum empréstimo novo para pagar dívida existente sem comparar custo total.',3),(h,'Receita extraordinária não aumenta automaticamente o padrão de gasto.',4),(h,'Primeira meta de reserva: R$ 3.000.',5);
end $$;
revoke all on function public.load_my_initial_data() from public,anon; grant execute on function public.load_my_initial_data() to authenticated;
