import { useMemo, useState } from "react";
import { ViewFrame } from "../components/ViewFrame";
import { useHubView } from "../hooks/useHubView";
import { useHub } from "../store/HubContext";
import type { SellData } from "../types";
export function SellView() {
  const hub = useHub(), view = useHubView<SellData>({ kind: "hub", route: "sell" }); const data = view.data;
  const [selected, setSelected] = useState<Record<string, number>>({}); const [busy, setBusy] = useState(false);
  const subtotal = (group: NonNullable<typeof data>["groups"][number]) => Math.floor((selected[group.key] ?? 0)
    * (group.basePrice ?? group.unitPrice) * (group.multiplier ?? 1) * (1 + (data?.sellBonus ?? 0)) + .5);
  const total = useMemo(() => data?.groups.reduce((sum, group) => sum + Math.floor((selected[group.key] ?? 0)
    * (group.basePrice ?? group.unitPrice) * (group.multiplier ?? 1) * (1 + data.sellBonus) + .5), 0) ?? 0, [data, selected]);
  const sellAll = () => setSelected(Object.fromEntries(data?.groups.map(group => [group.key, group.quantity]) ?? []));
  const confirmSale = async () => { setBusy(true); await hub.adapter.dispatch({ type: "sell.confirm", input: { selections: selected, operationId: crypto.randomUUID() } }); setBusy(false); setSelected({}); await view.reload(); };
  return <ViewFrame title="Sell Produce" eyebrow="QUALITY-BASED PERSONAL BUYER" state={view.state} error={view.error}>{data && <>
    <div className="notice">Only produce created by this resource and harvested by you is eligible. Level bonus: +{Math.round(data.sellBonus * 100)}%.</div>
    <div className="sell-layout"><article className="panel"><div className="panel-heading"><h2>Eligible inventory</h2><button onClick={sellAll}>Select all</button></div>
      {data.groups.length ? data.groups.map(group => <div className="sell-row" key={group.key}><div><strong>{group.cropType}</strong><span className={`quality ${group.tier}`}>{group.tier}</span></div><small>{group.quantity} available · ${group.unitPrice}/unit</small>
        <input aria-label={`${group.key} quantity`} type="number" min="0" max={group.quantity} value={selected[group.key] ?? 0} onChange={event => setSelected(current => ({ ...current, [group.key]: Math.max(0, Math.min(group.quantity, Number(event.target.value))) }))} /></div>) : <div className="empty">No eligible harvest in your inventory.</div>}</article>
      <aside className="receipt"><span>EXACT PREVIEW</span>{data.groups.filter(group => selected[group.key]).map(group => <div key={group.key}><small>{selected[group.key]} × {group.cropType} ({group.tier})</small><b>${subtotal(group).toLocaleString()}</b></div>)}<hr /><strong>${total.toLocaleString()}</strong>
        {hub.surface === "sell" ? <button disabled={busy || total <= 0} onClick={() => confirm("Confirm this exact sale?") && void confirmSale()}>Confirm sale</button>
          : <button onClick={() => void hub.adapter.dispatch({ type: "sell.setRoute" })}>Route to Grapeseed buyer</button>}</aside></div>
  </>}</ViewFrame>;
}
