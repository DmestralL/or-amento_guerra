"use client";
import { useCallback, useEffect, useMemo, useState } from "react";
import {
  ArrowLeft,
  Check,
  Landmark,
  Plus,
  Save,
  Trash2,
  WalletCards,
  X,
} from "lucide-react";
import { brl } from "@/lib/format";
import { createClient } from "@/lib/supabase/client";
import type { TransactionItem } from "@/components/transaction-history";
import {
  accountBalance,
  financialPosition,
} from "@/lib/financial-calculations";

export type AccountItem = {
  id: string;
  name: string;
  kind: string;
  openingBalance: number;
  available: boolean;
  valueStatus: string;
};
type DbAccount = {
  id: string;
  name: string;
  kind: string;
  opening_balance: number | string;
  available_for_spending: boolean;
  value_status: string;
};
type ProtectedFund = {
  id: string;
  name: string;
  amount: number;
  protectedUntil: string | null;
  includedInAccountBalance: boolean;
};
const labels: Record<string, string> = {
  checking: "Conta corrente",
  savings: "Poupança",
  cash: "Dinheiro",
  benefit: "Benefício",
  reserve: "Reserva",
  asset: "Patrimônio",
};
const parseMoney = (value: string) =>
  Number(value.replaceAll(".", "").replace(",", "."));

export function WalletAccounts({
  householdId,
  txs,
  back,
}: {
  householdId: string;
  txs: TransactionItem[];
  back: () => void;
}) {
  const [accounts, setAccounts] = useState<AccountItem[]>([]),
    [funds, setFunds] = useState<ProtectedFund[]>([]),
    [editing, setEditing] = useState<AccountItem | null>(null),
    [adding, setAdding] = useState(false),
    [reportedBalance, setReportedBalance] = useState(""),
    [reconciling, setReconciling] = useState(false),
    [message, setMessage] = useState("");
  const load = useCallback(async () => {
    if (!householdId) return;
    const sb = createClient();
    const [{ data, error }, { data: protectedRows }] = await Promise.all([
      sb
        .from("accounts")
        .select(
          "id,name,kind,opening_balance,available_for_spending,value_status",
        )
        .eq("household_id", householdId)
        .order("created_at"),
      sb
        .from("protected_funds")
        .select("id,name,amount,protected_until,included_in_account_balance")
        .eq("household_id", householdId)
        .eq("active", true)
        .order("created_at"),
    ]);
    if (error) {
      setMessage(error.message);
      return;
    }
    setAccounts(
      ((data ?? []) as DbAccount[]).map((a) => ({
        id: a.id,
        name: a.name,
        kind: a.kind,
        openingBalance: Number(a.opening_balance),
        available: a.available_for_spending,
        valueStatus: a.value_status,
      })),
    );
    setFunds(
      (protectedRows ?? []).map((x) => ({
        id: x.id,
        name: x.name,
        amount: Number(x.amount),
        protectedUntil: x.protected_until,
        includedInAccountBalance: x.included_in_account_balance,
      })),
    );
  }, [householdId]);
  useEffect(() => {
    queueMicrotask(() => void load());
  }, [load]);
  useEffect(() => {
    if (!householdId) return;
    const sb = createClient(),
      channel = sb
        .channel(`family-accounts-${householdId}`)
        .on(
          "postgres_changes",
          {
            event: "*",
            schema: "public",
            table: "accounts",
            filter: `household_id=eq.${householdId}`,
          },
          () => void load(),
        )
        .on(
          "postgres_changes",
          {
            event: "*",
            schema: "public",
            table: "protected_funds",
            filter: `household_id=eq.${householdId}`,
          },
          () => void load(),
        )
        .subscribe();
    return () => {
      void sb.removeChannel(channel);
    };
  }, [householdId, load]);
  const totals = useMemo(() => {
    const opening = accounts
        .filter((a) => a.available)
        .reduce((s, a) => s + a.openingBalance, 0),
      income = txs
        .filter((t) => t.type === "income" && (t.affectsCash ?? true))
        .reduce((s, t) => s + t.amount, 0),
      out = txs
        .filter(
          (t) =>
            (t.type === "expense" || t.type === "debt_payment") &&
            (t.affectsCash ?? !t.cardId),
        )
        .reduce((s, t) => s + t.amount, 0),
      card = txs
        .filter((t) => t.type === "expense" && t.cardId)
        .reduce((s, t) => s + t.amount, 0);
    const movements = txs.map((t) => ({
      ...t,
      affectsCash:
        t.affectsCash ??
        (t.type === "income" ||
          ((t.type === "expense" || t.type === "debt_payment") && !t.cardId)),
      affectsBudget:
        t.affectsBudget ?? (t.type === "expense" || t.type === "debt_payment"),
    }));
    const balance = accountBalance(opening, movements);
    const position = financialPosition(balance, funds);
    return {
      opening,
      income,
      out,
      card,
      balance,
      protectedTotal: position.protectedTotal,
      real: position.available,
      patrimony: position.patrimony,
    };
  }, [accounts, funds, txs]);
  async function editFund(fund?: ProtectedFund) {
    const name =
      fund?.name ?? prompt("Nome do valor protegido:", "Nova caixinha");
    if (!name) return;
    const raw = prompt(
      `Valor protegido em ${name}:`,
      fund ? fund.amount.toFixed(2).replace(".", ",") : "0,00",
    );
    if (raw == null) return;
    const amount = parseMoney(raw);
    if (!Number.isFinite(amount) || amount < 0) {
      setMessage("Informe um valor válido.");
      return;
    }
    const sb = createClient(),
      {
        data: { user },
      } = await sb.auth.getUser();
    const result = fund
      ? await sb
          .from("protected_funds")
          .update({ amount, updated_at: new Date().toISOString() })
          .eq("id", fund.id)
          .eq("household_id", householdId)
      : await sb.from("protected_funds").insert({
          household_id: householdId,
          name,
          amount,
          active: true,
          value_status: "confirmed",
          included_in_account_balance: false,
          source_account_id: accounts.find((x) => x.available)?.id ?? null,
          created_by: user?.id,
        });
    setMessage(
      result.error
        ? result.error.message
        : "Dinheiro protegido atualizado sem registrar despesa.",
    );
    if (!result.error) await load();
  }
  async function reconcile() {
    const reported = parseMoney(reportedBalance),
      account = accounts.find((x) => x.available);
    if (!account || !Number.isFinite(reported) || reported < 0) {
      setMessage("Informe um saldo bancário válido.");
      return;
    }
    setReconciling(true);
    const { error } = await createClient().rpc("reconcile_account_balance", {
      target_account_id: account.id,
      reported_balance: reported,
    });
    setReconciling(false);
    if (error) {
      setMessage(error.message);
      return;
    }
    setReportedBalance("");
    setMessage("Saldo-base reconciliado sem criar receita ou despesa.");
    await load();
  }
  async function remove(account: AccountItem) {
    if (!confirm(`Excluir ${account.name}?`)) return;
    const { error } = await createClient()
      .from("accounts")
      .delete()
      .eq("id", account.id)
      .eq("household_id", householdId);
    setMessage(error ? error.message : "Conta removida.");
    if (!error) await load();
  }
  return (
    <div className="space-y-5">
      <div className="flex items-center gap-3">
        <button
          onClick={back}
          className="tap focus-ring grid w-12 place-items-center rounded-2xl bg-white"
          aria-label="Voltar"
        >
          <ArrowLeft />
        </button>
        <div>
          <p className="label">Saldo e contas</p>
          <h2 className="text-3xl font-black">Minha carteira</h2>
        </div>
      </div>
      {message && (
        <div
          role="status"
          className="rounded-2xl bg-mint p-4 text-sm font-bold"
        >
          {message}
        </div>
      )}
      <section className="rounded-[2rem] bg-ink p-6 text-white shadow-soft">
        <div className="flex justify-between">
          <div>
            <p className="text-sm text-white/60">Disponível real</p>
            <p className="money mt-1 text-4xl font-black">{brl(totals.real)}</p>
          </div>
          <WalletCards className="text-lime" />
        </div>
        <div className="mt-6 grid grid-cols-3 gap-3 border-t border-white/15 pt-5 text-xs">
          <span>
            Saldo em contas
            <br />
            <b className="money text-base">{brl(totals.balance)}</b>
          </span>
          <span>
            Protegido
            <br />
            <b className="money text-base text-lime">
              {brl(totals.protectedTotal)}
            </b>
          </span>
          <span>
            Patrimônio total
            <br />
            <b className="money text-base">{brl(totals.patrimony)}</b>
          </span>
        </div>
      </section>
      <section className="card p-5">
        <p className="label">Reconciliação bancária</p>
        <h3 className="text-xl font-black">Conferir com o banco</h3>
        <div className="mt-4 grid gap-3 sm:grid-cols-3">
          <div className="rounded-xl bg-cream p-3">
            <small>Calculado no app</small>
            <b className="money block">{brl(totals.balance)}</b>
          </div>
          <label className="rounded-xl border p-3">
            <small>Saldo informado pelo banco</small>
            <input
              inputMode="decimal"
              value={reportedBalance}
              onChange={(e) => setReportedBalance(e.target.value)}
              placeholder="0,00"
              className="money mt-1 w-full bg-transparent text-lg font-black outline-none"
            />
          </label>
          <div className="rounded-xl bg-cream p-3">
            <small>Diferença</small>
            <b className="money block">
              {reportedBalance && Number.isFinite(parseMoney(reportedBalance))
                ? brl(parseMoney(reportedBalance) - totals.balance)
                : "—"}
            </b>
          </div>
        </div>
        <button
          disabled={reconciling || !reportedBalance}
          onClick={() => void reconcile()}
          className="tap mt-3 w-full rounded-xl bg-ink p-3 font-bold text-white disabled:opacity-40"
        >
          {reconciling ? "Reconciliando…" : "Ajustar saldo-base"}
        </button>
        <p className="mt-2 text-xs text-ink/55">
          O ajuste corrige a base da conta e fica no histórico. Não cria receita
          nem despesa.
        </p>
      </section>
      <section className="card p-5">
        <div className="flex items-center justify-between">
          <div>
            <p className="label">Dinheiro protegido</p>
            <h3 className="text-xl font-black">Reservas e caixinhas</h3>
          </div>
          <button
            onClick={() => void editFund()}
            className="tap rounded-xl bg-lime px-3 text-sm font-black"
          >
            + Caixinha
          </button>
        </div>
        <div className="mt-3 divide-y divide-ink/10">
          {funds.map((fund) => (
            <button
              key={fund.id}
              onClick={() => void editFund(fund)}
              className="tap flex w-full justify-between py-3 text-left"
            >
              <span>
                <b>{fund.name}</b>
                <small className="block text-ink/55">
                  Não é despesa ·{" "}
                  {fund.includedInAccountBalance
                    ? "incluída no saldo da conta"
                    : "já separada do saldo da conta"}
                  {fund.protectedUntil
                    ? ` · protegido até ${new Date(`${fund.protectedUntil}T12:00:00`).toLocaleDateString("pt-BR")}`
                    : ""}
                </small>
              </span>
              <strong className="money">{brl(fund.amount)}</strong>
            </button>
          ))}
        </div>
      </section>
      <section className="card p-5">
        <p className="label">Como o saldo é calculado</p>
        <p className="mt-2 text-sm text-ink/65">
          Saldo inicial das contas disponíveis + receitas − despesas pagas fora
          do cartão.
        </p>
        <div className="mt-3 rounded-xl bg-amber-50 p-3 text-sm">
          <b>{brl(totals.card)}</b> em compras no cartão não reduz este saldo
          agora; entra na saída quando a fatura for paga.
        </div>
      </section>
      <div className="flex items-center justify-between">
        <h3 className="text-xl font-black">Contas e carteiras</h3>
        <button
          onClick={() => setAdding(true)}
          className="tap flex items-center gap-2 rounded-xl bg-lime px-4 text-sm font-black"
        >
          <Plus size={17} /> Adicionar
        </button>
      </div>
      <section className="card divide-y divide-ink/10">
        {accounts.map((account) => (
          <article key={account.id} className="flex items-center gap-3 p-4">
            <span className="grid h-11 w-11 place-items-center rounded-2xl bg-mint">
              {account.kind === "cash" ? <WalletCards /> : <Landmark />}
            </span>
            <div className="min-w-0 flex-1">
              <b>{account.name}</b>
              <p className="text-xs text-ink/55">
                {labels[account.kind] || account.kind} ·{" "}
                {account.available ? "entra no saldo" : "separada do saldo"}
              </p>
            </div>
            <strong className="money">{brl(account.openingBalance)}</strong>
            <button
              onClick={() => setEditing(account)}
              className="tap rounded-lg px-2 text-xs font-bold"
            >
              Editar
            </button>
          </article>
        ))}
      </section>
      {(adding || editing) && (
        <AccountForm
          householdId={householdId}
          account={editing}
          close={() => {
            setAdding(false);
            setEditing(null);
          }}
          saved={async (text) => {
            setAdding(false);
            setEditing(null);
            setMessage(text);
            await load();
          }}
          remove={editing ? () => void remove(editing) : undefined}
        />
      )}
    </div>
  );
}

function AccountForm({
  householdId,
  account,
  close,
  saved,
  remove,
}: {
  householdId: string;
  account: AccountItem | null;
  close: () => void;
  saved: (message: string) => void;
  remove?: () => void;
}) {
  const [name, setName] = useState(account?.name || ""),
    [kind, setKind] = useState(account?.kind || "checking"),
    [amount, setAmount] = useState(
      account ? String(account.openingBalance).replace(".", ",") : "",
    ),
    [available, setAvailable] = useState(account?.available ?? true),
    [busy, setBusy] = useState(false),
    [error, setError] = useState("");
  async function save() {
    const value = parseMoney(amount);
    if (!name.trim() || Number.isNaN(value)) {
      setError("Informe nome e saldo inicial válido.");
      return;
    }
    setBusy(true);
    const sb = createClient(),
      payload = {
        household_id: householdId,
        name: name.trim(),
        kind,
        opening_balance: value,
        available_for_spending: available,
        value_status: "confirmed",
      };
    let result;
    if (account)
      result = await sb
        .from("accounts")
        .update(payload)
        .eq("id", account.id)
        .eq("household_id", householdId);
    else {
      const {
        data: { user },
      } = await sb.auth.getUser();
      result = await sb
        .from("accounts")
        .insert({ ...payload, created_by: user?.id });
    }
    setBusy(false);
    if (result.error) {
      setError(result.error.message);
      return;
    }
    await saved(
      account
        ? "Conta atualizada e saldo recalculado."
        : "Conta adicionada e saldo recalculado.",
    );
  }
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-ink/45 sm:items-center sm:p-4">
      <div className="w-full max-w-lg rounded-t-[2rem] bg-white p-5 sm:rounded-[2rem]">
        <div className="flex justify-between">
          <div>
            <p className="label">{account ? "Editar" : "Nova"}</p>
            <h3 className="text-2xl font-black">Conta ou carteira</h3>
          </div>
          <button onClick={close} className="tap grid w-12 place-items-center">
            <X />
          </button>
        </div>
        <div className="mt-4 grid gap-3 sm:grid-cols-2">
          <label className="sm:col-span-2">
            <span className="label">Nome</span>
            <input
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Ex.: Conta Nubank"
              className="tap mt-1 w-full rounded-xl border px-3"
            />
          </label>
          <label>
            <span className="label">Tipo</span>
            <select
              value={kind}
              onChange={(e) => setKind(e.target.value)}
              className="tap mt-1 w-full rounded-xl border bg-white px-3"
            >
              {Object.entries(labels).map(([value, label]) => (
                <option key={value} value={value}>
                  {label}
                </option>
              ))}
            </select>
          </label>
          <label>
            <span className="label">Saldo inicial</span>
            <input
              inputMode="decimal"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="tap mt-1 w-full rounded-xl border px-3"
            />
          </label>
          <label className="flex items-center gap-2 sm:col-span-2">
            <input
              type="checkbox"
              checked={available}
              onChange={(e) => setAvailable(e.target.checked)}
            />
            <span className="text-sm font-bold">Disponível para gastar</span>
          </label>
        </div>
        {error && (
          <p className="mt-3 text-sm font-bold text-red-700">{error}</p>
        )}
        <div className="mt-4 flex gap-2">
          {remove && (
            <button
              onClick={remove}
              className="tap grid w-12 place-items-center rounded-xl border text-red-700"
              aria-label="Excluir"
            >
              <Trash2 size={17} />
            </button>
          )}
          <button
            disabled={busy}
            onClick={() => void save()}
            className="tap flex flex-1 items-center justify-center gap-2 rounded-xl bg-ink font-bold text-white"
          >
            <Save size={17} />
            {busy ? "Salvando…" : "Salvar e recalcular"}
          </button>
        </div>
        <p className="mt-3 flex items-center gap-2 text-xs text-ink/55">
          <Check size={14} /> Alterações sincronizadas com a família.
        </p>
      </div>
    </div>
  );
}
