alter table public.debts replica identity full;
alter table public.debt_payments replica identity full;

do $$
begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='debts') then
  alter publication supabase_realtime add table public.debts;
 end if;
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='debt_payments') then
  alter publication supabase_realtime add table public.debt_payments;
 end if;
end $$;
