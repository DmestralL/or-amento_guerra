begin;
select plan(4);
select has_table('public','transactions','transactions exists');
select policies_are('public','transactions',array['transactions_delete','transactions_insert','transactions_select','transactions_update'],'all transaction policies exist');
select policies_are('public','planned_income',array['planned_income_delete','planned_income_insert','planned_income_select','planned_income_update'],'planned income isolated');
select row_security_active('public.transactions'::regclass),'RLS active on transactions';
select * from finish();
rollback;
