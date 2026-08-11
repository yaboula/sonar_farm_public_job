import { useMemo, useState } from "react";
import { ViewFrame } from "../components/ViewFrame";
import { useHubView } from "../hooks/useHubView";
import { useHub } from "../store/HubContext";
import type { MarketData } from "../types";
export function MarketView() {
  const hub = useHub(), view = useHubView<MarketData>({ kind: "hub", route: "market" });
  const [cart, setCart] = useState<Record<string, number>>({}); const [busy, setBusy] = useState(false); const data = view.data;
  const total = useMemo(() => data?.products.reduce((sum, item) => sum + (cart[item.id] ?? 0) * item.price, 0) ?? 0, [cart, data]);
  const change = (id: string, value: number) => setCart(current => ({ ...current, [id]: Math.max(0, Math.min(99, value)) }));
  const purchase = async () => { const lines = Object.entries(cart).filter(([, quantity]) => quantity > 0).map(([itemId, quantity]) => ({ itemId, quantity }));
    setBusy(true); const result = await hub.adapter.dispatch({ type: "market.purchase", input: { lines, operationId: crypto.randomUUID() } }); setBusy(false);
    if (result.ok) { setCart({}); await view.reload(); } };
  return <ViewFrame title="Personal Market" eyebrow="IMMEDIATE INVENTORY DELIVERY" state={view.state} error={view.error}>{data && <>
    <div className="notice">Bank payment · Maximum 10 product lines · Plus stock {data.stock.plus ?? 0} · Pro stock {data.stock.pro ?? 0}</div>
    <div className="market-layout"><div className="product-grid">{data.products.map(item => { const disabled = !item.unlocked || item.owned || (item.physicalOnly && hub.surface !== "market"); return <article className={`product-card tier-${item.tier}`} key={item.id}>
      <div><span>{item.category}</span><b>{item.tier.toUpperCase()}</b></div><h2>{item.label}</h2><p>{item.description}</p>
      <small>{item.stock == null ? "Unlimited" : `${item.stock} global stock`} · L{item.requiredLevel}</small>
      <footer><strong>${item.price.toLocaleString()}</strong><input aria-label={`${item.label} quantity`} type="number" min="0" max="99" value={cart[item.id] ?? 0} disabled={disabled} onChange={event => change(item.id, Number(event.target.value))} /></footer>
      {disabled ? <em>{item.owned ? "Already owned" : item.physicalOnly ? "Buy at a physical Market" : `Unlocks at level ${item.requiredLevel}`}</em> : null}
    </article>; })}</div><aside className="cart"><span>CART TOTAL</span><strong>${total.toLocaleString()}</strong><p>{Object.values(cart).filter(Boolean).length} / 10 lines</p><button disabled={busy || total <= 0 || Object.values(cart).filter(Boolean).length > 10} onClick={() => void purchase()}>Pay from bank</button></aside></div>
  </>}</ViewFrame>;
}
