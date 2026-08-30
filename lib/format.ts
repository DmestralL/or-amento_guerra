export const brl=(value:number)=>new Intl.NumberFormat("pt-BR",{style:"currency",currency:"BRL"}).format(value);
export const brDate=(value:string|Date)=>new Intl.DateTimeFormat("pt-BR").format(new Date(value));
export type MonthStatus="NO CAMINHO"|"ATENÇÃO"|"ESTOUROU";
export function monthStatus(spent:number,budget:number,day:number,days=30):MonthStatus{const used=spent/budget;if(used>1)return "ESTOUROU";const elapsed=day/days;return used>elapsed+.2?"ATENÇÃO":"NO CAMINHO"}
