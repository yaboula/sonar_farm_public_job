import { CaretRight, CheckCircle, Coins, MapPin, Minus, Package, Plus, Scales } from "@phosphor-icons/react";
import { useMemo, useRef, useState } from "react";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { HubScaffold } from "../components/HubScaffold";
import { StatePanel } from "../components/StatePanel";
import { useHubView } from "../hooks/useHubView";
import { useHub } from "../store/HubContext";
import { rejectionMessage } from "../utils/rejectionMessage";
import { money } from "../utils/format";
import type { SellData, SellGroup } from "../types";

const cropLabel = (value: string) => value.charAt(0).toUpperCase() + value.slice(1);
function lineTotal(group: SellGroup, quantity: number, bonus: number) {
  return Math.floor(quantity * (group.basePrice ?? group.unitPrice) * (group.multiplier ?? 1) * (1 + bonus) + 0.5);
}

export function SellView() {
  const hub = useHub();
  const view = useHubView<SellData>({ kind: "hub", route: "sell" });
  const [selected, setSelected] = useState<Record<string, number>>({});
  const [busy, setBusy] = useState(false);
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [notice, setNotice] = useState<string>();
  const operationRef = useRef<string | undefined>(undefined);
  const data = view.data;
  const total = useMemo(() => data?.groups.reduce((sum, group) => sum + lineTotal(group, selected[group.key] ?? 0, data.sellBonus), 0) ?? 0, [data, selected]);
  if (view.state !== "ready") return <StatePanel state={view.state} onAction={() => void view.reload()} />;
  if (!data) return <StatePanel state="empty" />;

  const change = (group: SellGroup, delta: number) => {
    operationRef.current = undefined;
    setSelected((current) => ({ ...current, [group.key]: Math.max(0, Math.min(group.quantity, (current[group.key] ?? 0) + delta)) }));
  };
  const sellAll = () => { operationRef.current = undefined; setSelected(Object.fromEntries(data.groups.map((group) => [group.key, group.quantity]))); };
  const selectedGroups = data.groups.filter((group) => (selected[group.key] ?? 0) > 0);
  const confirmSale = async () => {
    operationRef.current ??= crypto.randomUUID();
    setBusy(true);
    const result = await hub.adapter.dispatch({ type: "sell.confirm", input: { selections: Object.fromEntries(selectedGroups.map((group) => [group.key, selected[group.key]])), operationId: operationRef.current } });
    setBusy(false);
    setNotice(result.message ?? (result.ok ? `Sale completed for $${total.toLocaleString()}.` : rejectionMessage(result.reason, "Sale rejected.")));
    if (result.ok) { operationRef.current = undefined; setSelected({}); setConfirmOpen(false); await view.reload(); }
  };
  const setRoute = async () => {
    const result = await hub.adapter.dispatch({ type: "sell.setRoute" });
    setNotice(result.message ?? (result.ok ? "Route set to the Grapeseed buyer." : rejectionMessage(result.reason, "Route unavailable.")));
  };

  const toolbar = <><div className="hub-tabs"><button type="button" className="is-selected">Eligible Produce</button></div><div className="sell-bonus-chip"><Coins size={17} />Level bonus <strong>+{Math.round(data.sellBonus * 100)}%</strong></div><button className="toolbar-action" type="button" disabled={!data.groups.length} onClick={sellAll}>Select all eligible</button></>;
  const aside = <div className="detail-inspector sell-inspector"><span className="inspector-kicker">Exact preview</span><Scales size={38} weight="thin" /><h2>{selectedGroups.length ? `${selectedGroups.length} quality lot${selectedGroups.length === 1 ? "" : "s"}` : "Nothing selected"}</h2><p>Quality price, then your personal level bonus</p><div className="sell-bank-summary"><span>Personal bank</span><strong>{money(data.bankBalance)}</strong><small>{selectedGroups.length ? `After sale ${money(data.bankBalance + total)}` : "Credit is immediate after confirmation"}</small></div><div className="inspector-rule" />{selectedGroups.length ? <div className="sell-preview-lines">{selectedGroups.map((group) => <div key={group.key}><span>{selected[group.key]}× {cropLabel(group.cropType)} <small>{group.tier}</small></span><strong>{money(lineTotal(group, selected[group.key], data.sellBonus))}</strong></div>)}</div> : <p className="inspector-description">Select quantities from your eligible harvest. Only produce created by this resource and harvested by you appears here.</p>}<div className="supply-cart-total"><span>Bank credit</span><strong>{money(total)}</strong></div><div className="physical-note">{hub.surface === "sell" ? <CheckCircle size={19} /> : <MapPin size={19} />}<span>{hub.surface === "sell" ? "You are present at the authorized Grapeseed buyer." : "Remote tablet is preview-only. Mark the buyer route to sell."}</span></div>{hub.surface === "sell" ? <button className="inspector-action" type="button" disabled={!selectedGroups.length || busy} onClick={() => setConfirmOpen(true)}>Review Sale<CaretRight size={18} /></button> : <button className="inspector-action" type="button" onClick={() => void setRoute()}>Route to Buyer<MapPin size={18} /></button>}</div>;

  return <HubScaffold eyebrow="Personal produce buyer" title="Sell" subtitle="Sell only your own verified harvest at a quality-based price." toolbar={toolbar} aside={aside}>
    {notice ? <div className="domain-notice domain-notice--inline" role="status" aria-live="polite">{notice}</div> : null}
    <div className="sell-catalog">{data.groups.length ? data.groups.map((group) => {
      const quantity = selected[group.key] ?? 0;
      const qualityUnit = (group.basePrice ?? group.unitPrice) * (group.multiplier ?? 1);
      return <article className={`sell-lot${quantity ? " is-selected" : ""}`} key={group.key}><div className="sell-lot-art"><img src={`assets/items/${group.itemId}.png`} alt="" /></div><div className="sell-lot-main"><div><span>Verified harvest</span><span className={`quality ${group.tier}`}>{group.tier}</span></div><h2>{cropLabel(group.cropType)}</h2><p>{group.quantity} eligible units in your inventory</p><div className="sell-lot-price"><span><Package size={16} />{group.quantity} available</span><strong>{money(qualityUnit)}/unit + {Math.round(data.sellBonus * 100)}%</strong></div></div><div className="sell-lot-controls"><small>Quantity</small><div className="quantity-control"><button type="button" aria-label={`Remove ${group.cropType}`} disabled={!quantity} onClick={() => change(group, -1)}><Minus size={16} /></button><strong>{quantity}</strong><button type="button" aria-label={`Add ${group.cropType}`} disabled={quantity >= group.quantity} onClick={() => change(group, 1)}><Plus size={16} /></button></div><span>{money(lineTotal(group, quantity, data.sellBonus))}</span></div></article>;
    }) : <div className="inline-empty">No eligible harvest is currently in your inventory.</div>}</div>
    {confirmOpen ? <ConfirmDialog eyebrow="Personal produce sale" title="Confirm this exact sale?" confirmLabel={`Sell for ${money(total)}`} pending={busy} onClose={() => setConfirmOpen(false)} onConfirm={() => void confirmSale()}><div className="confirmation-lines">{selectedGroups.map((group) => <div key={group.key}><span>{selected[group.key]}× {cropLabel(group.cropType)} · {group.tier}</span><strong>{money(lineTotal(group, selected[group.key], data.sellBonus))}</strong></div>)}</div><div className="confirmation-facts"><div><span>Personal bonus</span><strong>+{Math.round(data.sellBonus * 100)}%</strong></div><div><span>Bank before</span><strong>{money(data.bankBalance)}</strong></div><div><span>Bank after</span><strong>{money(data.bankBalance + total)}</strong></div></div><div className="confirmation-total"><span>Personal bank credit</span><strong>{money(total)}</strong></div><p>The server will revalidate producer metadata, inventory quantities and this operation ID before crediting your bank.</p></ConfirmDialog> : null}
  </HubScaffold>;
}
