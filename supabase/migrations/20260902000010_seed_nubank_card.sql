insert into public.credit_cards(household_id,name,credit_limit,closing_day,due_day,active)
select h.id,'Nubank',1600,17,22,true
from public.households h
where h.name='Família Fonseca'
  and not exists (
    select 1 from public.credit_cards c
    where c.household_id=h.id and lower(c.name)='nubank'
  );
