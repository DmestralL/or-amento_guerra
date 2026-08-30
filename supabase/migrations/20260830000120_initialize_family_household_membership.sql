-- One-time production initialization. Uses stable e-mail identities instead of generated UUIDs.
do $$
declare owner_id uuid; spouse_id uuid; family_id uuid;
begin
 select id into owner_id from auth.users where lower(email)=lower('dmestral@gmail.com');
 select id into spouse_id from auth.users where lower(email)=lower('camila.fonseca284@gmail.com');
 if owner_id is null then raise exception 'Administrador não encontrado'; end if;
 insert into public.profiles(id,display_name) values(owner_id,'Administrador') on conflict(id) do update set display_name=excluded.display_name;
 if spouse_id is not null then insert into public.profiles(id,display_name) values(spouse_id,'Camila') on conflict(id) do update set display_name=excluded.display_name; end if;
 select household_id into family_id from public.household_members where user_id=owner_id limit 1;
 if family_id is null then insert into public.households(name,created_by) values('Família Fonseca',owner_id) returning id into family_id; end if;
 insert into public.household_members(household_id,user_id,role) values(family_id,owner_id,'owner') on conflict(household_id,user_id) do update set role='owner';
 if spouse_id is not null then insert into public.household_members(household_id,user_id,role) values(family_id,spouse_id,'member') on conflict(household_id,user_id) do nothing; end if;
 insert into public.financial_goals(household_id,name,target_amount,current_amount,starts_on,active)
 select family_id,'Reserva de emergência',3000,1291.84,date '2026-09-01',true
 where not exists(select 1 from public.financial_goals where household_id=family_id and active);
end $$;
