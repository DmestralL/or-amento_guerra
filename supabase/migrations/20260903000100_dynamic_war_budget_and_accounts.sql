alter table public.households
 add column if not exists war_started_on date,
 add column if not exists war_duration_days integer not null default 90;

alter table public.households drop constraint if exists households_war_duration_check;
alter table public.households add constraint households_war_duration_check
 check (war_duration_days between 1 and 3650);

update public.households
set war_started_on=coalesce(war_started_on,(created_at at time zone 'America/Sao_Paulo')::date);

insert into public.accounts(household_id,name,kind,opening_balance,available_for_spending,value_status,created_by)
select h.id,'Carteira da família','checking',650,true,'confirmed',h.created_by
from public.households h
where not exists(select 1 from public.accounts a where a.household_id=h.id);

do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='accounts') then
  alter publication supabase_realtime add table public.accounts;
 end if;
end $$;

alter table public.accounts replica identity full;
