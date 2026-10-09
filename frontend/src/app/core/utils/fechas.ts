const dos = (n: number) => String(n).padStart(2, '0');

/** ISO del backend -> valor para <input type="datetime-local"> (hora local). */
export function isoAInputLocal(iso: string): string {
  const d = new Date(iso);
  return `${d.getFullYear()}-${dos(d.getMonth() + 1)}-${dos(d.getDate())}T${dos(d.getHours())}:${dos(d.getMinutes())}`;
}

/** Valor de <input type="datetime-local"> -> ISO para enviar al backend. */
export function inputLocalAIso(valor: string): string {
  return new Date(valor).toISOString();
}