import { CaretRight, MagnifyingGlass, Minus, Package, Plus, ShoppingCartSimple, Tag, LockKey } from "@phosphor-icons/react";
import { useMemo, useRef, useState } from "react";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { FarmSelect } from "../components/FarmSelect";
import { HubScaffold } from "../components/HubScaffold";
import { StatePanel } from "../components/StatePanel";
import { CANONICAL_MARKET_PRODUCTS } from "../data/itemCatalog.generated";
import { useHubView } from "../hooks/useHubView";
import { useHub } from "../store/HubContext";
import type { MarketData, MarketDisplayProduct, MarketProduct } from "../types";

const categoryOptions = ["All", "Access", "Seedlings", "Seeds", "Hand Tools", "Watering", "Fertilizer", "Pest Treatment"].map((value) => ({ value, label: value }));
const catalogById = new Map(CANONICAL_MARKET_PRODUCTS.map((item) => [item.id, item]));

function decorate(product: MarketProduct): MarketDisplayProduct {
  const catalog = catalogById.get(product.id);
  if (catalog) return { ...product, cropRelation: catalog.cropRelation, effect: catalog.effect, image: catalog.image, restock: catalog.restock, leadMinutes: catalog.leadMinutes, applications: catalog.applications };
  return { ...product, cropRelation: "Hub access", effect: "Opens the complete farming Hub remotely", image: "assets/items/farm_tablet.png", restock: "One per farmer", leadMinutes: 0, applications: 1 };
}

export function MarketView() {
  const hub = useHub();
  const view = useHubView<MarketData>({ kind: "hub", route: "market" });
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("All");
  const [cart, setCart] = useState<Record<string, number>>({});
  const [busy, setBusy] = useState(false);
  const [reviewOpen, setReviewOpen] = useState(false);
  const [notice, setNotice] = useState<string>();
  const operationRef = useRef<string | undefined>(undefined);
  const products = useMemo(() => (view.data?.products ?? []).map(decorate), [view.data?.products]);
  const visibleProducts = products.filter((item) => (category === "All" || item.category === category) && `${item.label} ${item.category} ${item.cropRelation}`.toLowerCase().includes(query.toLowerCase()));
  const lines = Object.entries(cart).filter(([, quantity]) => quantity > 0).map(([id, quantity]) => ({ product: products.find((item) => item.id === id), quantity })).filter((line): line is { product: MarketDisplayProduct; quantity: number } => Boolean(line.product));
  const total = lines.reduce((sum, line) => sum + line.product.price * line.quantity, 0);

  if (view.state !== "ready") return <StatePanel state={view.state} onAction={() => void view.reload()} />;
  if (!view.data) return <StatePanel state="empty" />;

  const adjust = (product: MarketDisplayProduct, delta: number) => {
    operationRef.current = undefined;
    setCart((current) => {
      const currentValue = current[product.id] ?? 0;
      if (delta > 0 && currentValue === 0 && Object.values(current).filter((value) => value > 0).length >= 10) return current;
      const max = product.stock == null ? 99 : Math.min(99, product.stock);
      return { ...current, [product.id]: Math.max(0, Math.min(max, currentValue + delta)) };
    });
  };

  const purchase = async () => {
    operationRef.current ??= crypto.randomUUID();
    setBusy(true);
    const result = await hub.adapter.dispatch({ type: "market.purchase", input: { lines: lines.map((line) => ({ itemId: line.product.id, quantity: line.quantity })), operationId: operationRef.current, physical: hub.surface === "market", marketId: hub.marketId } });
    setBusy(false);
    setNotice(result.message ?? (result.ok ? `Purchase completed for $${total.toLocaleString()}.` : result.reason ?? "Purchase rejected."));
    if (result.ok) { operationRef.current = undefined; setCart({}); setReviewOpen(false); await view.reload(); }
  };

  const toolbar = <><div className="hub-tabs supply-tabs" role="tablist"><button type="button" role="tab" aria-selected="true" className="is-selected">Personal Market</button></div><label className="search-control"><MagnifyingGlass size={18} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search products" /></label><FarmSelect className="toolbar-select" label="Category" value={category} options={categoryOptions} onChange={setCategory} /></>;
  const aside = <div className="detail-inspector supply-inspector"><span className="inspector-kicker">Purchase cart</span><ShoppingCartSimple size={38} weight="thin" /><h2>{lines.length ? `${lines.length} line${lines.length === 1 ? "" : "s"}` : "Cart empty"}</h2><p>Personal bank payment · immediate inventory delivery</p><div className="supply-payer-summary"><span>Purchase payer</span><strong>Personal Bank</strong><small>Server validates funds at confirmation</small></div><div className="inspector-rule" />{lines.length ? <div className="mini-cart">{lines.slice(0, 4).map((line) => <div key={line.product.id}><span className="mini-cart-quantity">{line.quantity}×</span><span className="mini-cart-name">{line.product.label}</span><strong>${(line.product.price * line.quantity).toLocaleString()}</strong></div>)}{lines.length > 4 ? <p className="mini-cart-more">+{lines.length - 4} more selected products</p> : null}</div> : <p className="inspector-description">Choose quantities from the catalog. Level, global stock, bank funds and inventory capacity are revalidated by the server.</p>}<div className="supply-cart-total"><span>Total</span><strong>${total.toLocaleString()}</strong></div><div className="physical-note"><Package size={19} /><span>{hub.surface === "market" ? "Physical Market: tablet purchase is available here." : "Tablet delivery is immediate. The tablet itself is sold only at a physical Market."}</span></div><button type="button" className="inspector-action" disabled={!lines.length || busy || lines.length > 10} onClick={() => setReviewOpen(true)}>Review Purchase<CaretRight size={18} /></button></div>;

  return <HubScaffold eyebrow="Materials & tools" title="Market" subtitle="Buy personal farming inputs with immediate delivery to your inventory." toolbar={toolbar} aside={aside}>
    {notice ? <div className="domain-notice domain-notice--inline">{notice}</div> : null}
    <div className="supply-grid">{visibleProducts.length ? visibleProducts.map((item) => {
      const quantity = cart[item.id] ?? 0;
      const physicallyBlocked = item.physicalOnly && hub.surface !== "market";
      const disabled = !item.unlocked || item.owned || physicallyBlocked || item.stock === 0;
      return <article className={`supply-card${quantity ? " is-selected" : ""}${disabled ? " is-disabled" : ""}`} key={item.id}>
        <div className="supply-card-intro"><div className="supply-card-head"><span>{item.category}</span><div className="supply-card-delivery"><small>{item.leadMinutes ? "Immediate" : "Physical only"}</small><span className="supply-card-tier" data-tier={item.tier}>{item.tier}</span></div></div><div className="supply-card-title-row"><h2>{item.label}</h2><div className="supply-card-visual"><img src={item.image} alt="" /></div></div></div>
        <p>{item.description}</p><small className="supply-effect">{item.effect}</small><small className="supply-crop">{item.cropRelation} · {item.applications} application{item.applications === 1 ? "" : "s"}</small>
        <div className="supply-meta"><span><Package size={16} />{item.stock == null ? "Unlimited stock" : item.stock === 0 ? "Sold out" : `${item.stock} global stock`}</span><strong><Tag size={16} />${item.price}</strong></div><div className="supply-owned"><span>Requires level {item.requiredLevel}</span><small>{item.restock}</small></div>
        {disabled ? <div className="supply-lock"><LockKey size={15} />{item.owned ? "Already owned" : physicallyBlocked ? "Buy at a physical Market" : !item.unlocked ? `Unlocks at level ${item.requiredLevel}` : "Out of stock"}</div> : <div className="quantity-control"><button type="button" aria-label={`Remove ${item.label}`} disabled={!quantity} onClick={() => adjust(item, -1)}><Minus size={16} /></button><strong>{quantity}</strong><button type="button" aria-label={`Add ${item.label}`} onClick={() => adjust(item, 1)}><Plus size={16} /></button></div>}
      </article>;
    }) : <div className="inline-empty">No products match this catalog filter.</div>}</div>
    {reviewOpen ? <ConfirmDialog eyebrow="Personal Market" title="Confirm this purchase?" confirmLabel={`Pay $${total.toLocaleString()}`} pending={busy} onClose={() => setReviewOpen(false)} onConfirm={() => void purchase()}><div className="confirmation-lines">{lines.map((line) => <div key={line.product.id}><span>{line.quantity}× {line.product.label}</span><strong>${(line.quantity * line.product.price).toLocaleString()}</strong></div>)}</div><div className="confirmation-total"><span>Personal bank total</span><strong>${total.toLocaleString()}</strong></div><p>Stock, funds and inventory capacity will be checked again. A rejected purchase keeps this cart intact.</p></ConfirmDialog> : null}
  </HubScaffold>;
}
