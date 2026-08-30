# Orçamento da Família

Aplicativo financeiro compartilhado, mobile-first, em português do Brasil. Inclui dashboard, lançamentos rápidos, orçamento mensal, Orçamento de Guerra de 90 dias, dívidas com nível de precisão, patrimônio separado, PWA, autenticação Supabase e isolamento por família via RLS.

## Requisitos

- Node.js 22+
- pnpm 10+
- Projeto Supabase

## Instalação local

1. Rode `pnpm install`.
2. Copie `.env.example` para `.env.local` e preencha a URL e a chave publicável do Supabase. Nunca use `service_role` no frontend.
3. No Supabase SQL Editor, execute `supabase/migrations/20260830000000_initial_schema.sql`.
4. Execute `supabase/seed_lucas_family.sql` para disponibilizar a função de carga inicial (ela não insere nada até ser chamada por um usuário autenticado).
5. Em Authentication > URL Configuration, defina `http://localhost:3000/auth/callback` como Redirect URL local.
6. Rode `pnpm dev` e abra `http://localhost:3000`.

O app abre com dados representativos para permitir inspeção visual sem credenciais. Quando as variáveis Supabase estão configuradas e o usuário está autenticado, novos lançamentos são persistidos com RLS.

## Criar o primeiro casal

1. A primeira pessoa cria a própria conta em `/login`; não existe senha padrão.
2. Após confirmar o e-mail, crie o household chamando a Server Action `createHousehold("Família")` a partir do fluxo administrativo.
3. Carregue os dados descritos no briefing uma única vez com a action `loadInitialData()` ou, autenticado, com `select public.load_my_initial_data();`. A coluna `initial_seed_applied_at` impede repetição.
4. O proprietário convida a segunda pessoa pelo e-mail. O registro em `household_invites` deve guardar somente o hash de um token aleatório, com validade curta. Após a pessoa criar a própria conta, o backend valida o token e cria `household_members`. Não compartilhe senhas.

## Segurança

- Todas as tabelas financeiras têm `household_id`, RLS habilitado e políticas separadas para leitura/escrita.
- A função privada de associação fixa `search_path`, tem execução revogada de `public` e filtra sempre por `auth.uid()`.
- `anon` não tem privilégios nas tabelas financeiras; `authenticated` precisa passar também pelas políticas de household.
- Valores estimados e a confirmar usam `value_status`; receitas previstas não viram transações até o recebimento.
- FGTS e patrimônio usam `available_for_spending = false`.
- O pagamento de dívida referencia uma transação e possui `payroll_deduction`, evitando duplicar consignados.
- Projetos, como Congresso, usam orçamento separado; a interface nunca os soma duas vezes ao limite mensal comum.

Depois de aplicar a migration, abra Database > Publications e confirme Realtime para `transactions`, `budget_categories` e `debts`. Em projetos criados após maio/2026, confirme também em Integrations > Data API que o schema `public` está exposto; a migration concede apenas os privilégios necessários ao papel autenticado.

## Verificações

```bash
pnpm lint
pnpm typecheck
pnpm test
pnpm build
```

Para os testes SQL, use Supabase CLI em ambiente local: `supabase test db`. O arquivo `supabase/tests/rls.sql` verifica presença das políticas e RLS. Para uma auditoria completa, crie dois usuários de household A e um usuário de household B e confirme que consultas do terceiro retornam zero linhas.

## Exportação

A tela “Mais” apresenta o ponto de entrada para CSV e backup JSON. A exportação deve consultar apenas as tabelas protegidas por RLS usando a sessão do usuário, incluindo `transactions`, `debts`, `monthly_budgets` e `budget_categories`. Não use uma chave administrativa para exportações do cliente.

## Deploy na Vercel

1. Envie este repositório para GitHub/GitLab/Bitbucket e importe-o na Vercel.
2. Framework preset: Next.js; Build command: `pnpm build`; Node.js: 22.
3. Cadastre `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` e `NEXT_PUBLIC_APP_URL` (a URL final HTTPS).
4. No Supabase, adicione `https://SEU-DOMINIO/auth/callback` em Authentication > Redirect URLs e a URL raiz em Site URL.
5. Faça o deploy. Depois, instale pelo menu “Adicionar à tela inicial” no Android/Chrome/Windows ou Compartilhar > Adicionar à Tela de Início no iPhone.

## Estrutura principal

```text
app/                 rotas, autenticação e shell Next.js
components/          dashboard e fluxos mobile
lib/                 regras, dados, actions e clientes Supabase
public/              manifest, ícone e service worker
supabase/migrations/ schema, índices, grants, RLS e Realtime
supabase/tests/      testes de políticas
supabase/seed_lucas_family.sql
```

## Observações financeiras preservadas

- O vale-alimentação é carteira separada, não saída de caixa.
- Horas extras, férias e 13º não aumentam automaticamente o orçamento.
- A parte restante do 13º já está na reserva e não é lançada novamente.
- Taxas de 3,21 e 3,63 permanecem sem periodicidade presumida.
- Financiamento da casa fica fora da dívida de consumo; o carro não gera um segundo financiamento.
