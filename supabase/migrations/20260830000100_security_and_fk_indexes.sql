-- Remove acesso externo de uma função administrativa preexistente sem apagá-la.
revoke all on function public.rls_auto_enable() from public, anon, authenticated;

-- Índices para filtros por household e relacionamentos usados no app/RLS.
create index if not exists households_created_by_idx on public.households(created_by);
create index if not exists household_invites_household_idx on public.household_invites(household_id);
create index if not exists household_invites_created_by_idx on public.household_invites(created_by);
create index if not exists accounts_household_idx on public.accounts(household_id);
create index if not exists accounts_created_by_idx on public.accounts(created_by);
create index if not exists transaction_categories_household_idx on public.transaction_categories(household_id);
create index if not exists transactions_account_idx on public.transactions(account_id);
create index if not exists transactions_created_by_idx on public.transactions(created_by);
create index if not exists monthly_budgets_created_by_idx on public.monthly_budgets(created_by);
create index if not exists budget_categories_household_idx on public.budget_categories(household_id);
create index if not exists budget_categories_category_idx on public.budget_categories(category_id);
create index if not exists credit_cards_household_idx on public.credit_cards(household_id);
create index if not exists credit_card_invoices_household_idx on public.credit_card_invoices(household_id);
create index if not exists credit_card_invoices_card_idx on public.credit_card_invoices(card_id);
create index if not exists debt_payments_household_idx on public.debt_payments(household_id);
create index if not exists debt_payments_debt_idx on public.debt_payments(debt_id);
create index if not exists debt_payments_transaction_idx on public.debt_payments(transaction_id);
create index if not exists debt_payments_created_by_idx on public.debt_payments(created_by);
create index if not exists financial_goals_household_idx on public.financial_goals(household_id);
create index if not exists recurring_transactions_household_idx on public.recurring_transactions(household_id);
create index if not exists recurring_transactions_category_idx on public.recurring_transactions(category_id);
create index if not exists planned_income_received_transaction_idx on public.planned_income(received_transaction_id);
create index if not exists weekly_reviews_created_by_idx on public.weekly_reviews(created_by);
create index if not exists monthly_reviews_household_idx on public.monthly_reviews(household_id);
create index if not exists assets_household_idx on public.assets(household_id);
create index if not exists financial_rules_household_idx on public.financial_rules(household_id);
