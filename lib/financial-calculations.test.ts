import { describe, expect, it } from "vitest";
import {
  accountBalance,
  availableReal,
  budgetSpent,
  cashForecast,
  type FinancialMovement,
} from "./financial-calculations";
const cash = (over: Partial<FinancialMovement>): FinancialMovement => ({
  type: "expense",
  amount: 100,
  date: "2026-09-06",
  affectsCash: true,
  affectsBudget: true,
  ...over,
});
describe("saldo real e competência", () => {
  it("subtrai valores protegidos sem reduzir o patrimônio em contas", () => {
    expect(availableReal(7320.17, 3300 + 1291.84)).toBeCloseTo(2728.33);
  });
  it("transferência para protegido não é despesa nem saída das contas", () => {
    const transfer = cash({
      type: "transfer",
      amount: 3300,
      affectsCash: false,
      affectsBudget: false,
    });
    expect(accountBalance(7320.17, [transfer])).toBe(7320.17);
    expect(budgetSpent([transfer], "2026-09")).toBe(0);
  });
  it("compra no cartão consome orçamento mas não caixa", () => {
    const card = cash({
      amount: 479.58,
      affectsCash: false,
      affectsBudget: true,
    });
    expect(accountBalance(1000, [card])).toBe(1000);
    expect(budgetSpent([card], "2026-09")).toBe(479.58);
  });
  it("pagamento da fatura reduz caixa sem contar orçamento de novo", () => {
    const card = cash({
        amount: 479.58,
        affectsCash: false,
        affectsBudget: true,
      }),
      invoice = cash({
        amount: 479.58,
        affectsCash: true,
        affectsBudget: false,
      });
    expect(accountBalance(1000, [card, invoice])).toBeCloseTo(520.42);
    expect(budgetSpent([card, invoice], "2026-09")).toBe(479.58);
  });
  it("receita prevista não entra na projeção até ser recebida", () => {
    expect(
      cashForecast(1000, [], [{ amount: 867.18, status: "planned" }]),
    ).toBe(1000);
    expect(
      cashForecast(1000, [], [{ amount: 867.18, status: "received" }]),
    ).toBeCloseTo(1867.18);
  });
});
