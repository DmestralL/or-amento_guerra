export type FinancialMovement = {
  type: "expense" | "income" | "transfer" | "debt_payment";
  amount: number;
  date: string;
  affectsCash: boolean;
  affectsBudget: boolean;
};

export function accountBalance(
  opening: number,
  movements: FinancialMovement[],
) {
  return movements.reduce((total, item) => {
    if (!item.affectsCash) return total;
    return item.type === "income"
      ? total + item.amount
      : item.type === "expense" || item.type === "debt_payment"
        ? total - item.amount
        : total;
  }, opening);
}
export function availableReal(balance: number, protectedAmount: number) {
  return balance - protectedAmount;
}
export function budgetSpent(movements: FinancialMovement[], month: string) {
  return movements
    .filter(
      (item) =>
        item.date.startsWith(month) &&
        item.affectsBudget &&
        (item.type === "expense" || item.type === "debt_payment"),
    )
    .reduce((sum, item) => sum + item.amount, 0);
}
export function cashForecast(
  real: number,
  obligations: { amount: number | null; status: string }[],
  expectedIncome: { amount: number | null; status: string }[] = [],
) {
  const bills = obligations
      .filter((x) => x.status === "planned")
      .reduce((s, x) => s + (x.amount || 0), 0),
    received = expectedIncome
      .filter((x) => x.status === "received")
      .reduce((s, x) => s + (x.amount || 0), 0);
  return real - bills + received;
}
