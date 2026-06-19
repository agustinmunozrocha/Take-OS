// Tasas tributarias chilenas — Etapa 1.
//
// Estado MUTABLE compartido: arrancan con defaults y dalBootTaxRates los
// sobrescribe al leerlos de la base (tabla tax_rates). Viven en window:
//   - el codigo clasico los LEE como globales (IVA, FACTOR_BOLETA, ...),
//   - este modulo los ESCRIBE via window.X (los modulos son modo estricto:
//     no se puede reasignar un global "a secas").

// Defaults (se setean al cargar el modulo, antes del arranque de la app):
window.IMPUESTO_HONORARIOS = 0.1525;          // concepto 'honorarios' (BHE)
window.IMPUESTO_BTE = 0.1525;                 // concepto 'retencion_bte' (BTE); default = BHE hasta tener dato
window.IVA = 0.19;                            // concepto 'iva'
window.FACTOR_BOLETA = 1 - window.IMPUESTO_HONORARIOS;
window.FACTOR_BTE = 1 - window.IMPUESTO_BTE;
window.TAX_RATES_SOURCE = 'default';          // pasa a 'supabase' si se cargaron las tasas

export async function dalBootTaxRates() {
  if (!sb) return false;
  try {
    const { data, error } = await sb.from('tax_rates').select('concepto,tasa,vigente_desde,vigente_hasta');
    if (error || !data || !data.length) return false;
    const hoy = new Date().toISOString().slice(0, 10);
    const vigente = {};
    data.forEach(r => {
      const desde = r.vigente_desde || '0000-01-01';
      const hasta = r.vigente_hasta || null;
      if (desde <= hoy && (!hasta || hasta > hoy)) {
        const key = String(r.concepto || '').toLowerCase().trim();   // V10: case-insensitive (el concepto del IVA viene 'IVA')
        const prev = vigente[key];
        if (!prev || desde > prev._desde) vigente[key] = { tasa: r.tasa, _desde: desde };
      }
    });
    const norm = (v) => { let n = Number(v); if (!isFinite(n)) return null; if (n > 1) n = n / 100; return n; };
    const iva = vigente['iva'] ? norm(vigente['iva'].tasa) : null;
    const hon = vigente['honorarios'] ? norm(vigente['honorarios'].tasa) : null;
    const bte = vigente['retencion_bte'] ? norm(vigente['retencion_bte'].tasa) : null;
    if (iva != null) window.IVA = iva;
    if (hon != null) { window.IMPUESTO_HONORARIOS = hon; window.FACTOR_BOLETA = 1 - hon; }
    if (bte != null) { window.IMPUESTO_BTE = bte; window.FACTOR_BTE = 1 - bte; }
    window.TAX_RATES_SOURCE = 'supabase';
    return true;
  } catch (e) {
    console.warn('[dal] tax_rates no disponible; se usan tasas por defecto', e);
    return false;
  }
}
