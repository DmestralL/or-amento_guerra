alter table public.budget_categories replica identity full;

do $$
begin
 if not exists (
  select 1 from pg_publication_tables
  where pubname='supabase_realtime' and schemaname='public' and tablename='budget_categories'
 ) then
  alter publication supabase_realtime add table public.budget_categories;
 end if;
end $$;
