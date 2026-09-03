do $$
declare family_id uuid;
begin
 select id into family_id from public.households where name='Família Fonseca' order by created_at limit 1;
 if family_id is null then raise exception 'Família não encontrada'; end if;
 if not exists(select 1 from public.debts where household_id=family_id) then
  insert into public.debts(household_id,creditor,debt_type,original_amount,balance,installment_amount,total_installments,current_installment,rate_reported,rate_notes,status,value_status,priority,notes) values
  (family_id,'Safra','Consignado CLT',15419.96,10229.92,950.80,24,12,3.21,'Periodicidade/CET a confirmar','Em dia','confirmed','Alta','Pagamento de contas/dívidas'),
  (family_id,'Banco do Brasil','Consignado CLT',10295.67,8528.20,536.70,36,14,3.63,'Periodicidade a confirmar','Em dia','estimated','Alta','Compra do automóvel'),
  (family_id,'Santander','Acordo',4000,null,103.58,48,22,null,null,'Em dia','to_confirm','Média','Saldo de quitação desconhecido'),
  (family_id,'Banco do Brasil','Cartão/dívida antiga',6000,6000,null,null,null,null,null,'Inadimplente','estimated','Planejar','Mais de 1 ano'),
  (family_id,'Caixa','Dívida de consumo',5000,5000,null,null,null,null,null,'Inadimplente','estimated','Planejar','Mais de 1 ano'),
  (family_id,'Telhanorte','Dívida de consumo',null,4500,null,null,null,null,null,'Valor a confirmar','to_confirm','Confirmar','Valor informado era limite total; dívida efetiva a confirmar'),
  (family_id,'Mercado Pago','Cartão',5000,5000,null,null,null,null,null,'Inadimplente','estimated','Planejar','Mais de 6 meses'),
  (family_id,'Financiamento da casa','Financiamento imobiliário',144000,146461.55,435,360,51,6.5,'Juros nominais informados','Em dia','confirmed','Patrimônio','Separado das dívidas de consumo; 309 meses restantes');
 end if;
end $$;
