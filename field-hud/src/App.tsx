import { CheckCircle } from "@phosphor-icons/react/CheckCircle";
import { Clock } from "@phosphor-icons/react/Clock";
import { Grains } from "@phosphor-icons/react/Grains";
import { Leaf } from "@phosphor-icons/react/Leaf";
import { MapPin } from "@phosphor-icons/react/MapPin";
import { Plant } from "@phosphor-icons/react/Plant";
import { ShieldWarning } from "@phosphor-icons/react/ShieldWarning";
import { UsersThree } from "@phosphor-icons/react/UsersThree";
import { Warning } from "@phosphor-icons/react/Warning";
import { useEffect, useMemo, useState } from "react";
import type { FieldHudMessage, FieldHudView, HudCounts } from "./types";

const EMPTY_COUNTS: HudCounts = { empty: 0, healthy: 0, care: 0, critical: 0, ready: 0, blocked: 0, own: 0 };
const GUIDE = ["Plant", "Maintain green", "Harvest", "Sell"];

function duration(seconds = 0) {
  const value = Math.max(0, Math.floor(seconds));
  const hours = Math.floor(value / 3600), minutes = Math.floor((value % 3600) / 60), secs = value % 60;
  return `${String(hours).padStart(2, "0")}:${String(minutes).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
}

function Stat({ tone, value, label }: { tone: string; value: number; label: string }) {
  return <div className="stat" data-tone={tone}><span>{label}</span><strong>{value}</strong></div>;
}

function tip(view: FieldHudView) {
  if (!view.state.access.allowed) return "Your rental continues. Return to the farmer job and go on duty to interact.";
  if (view.state.reservation.status === "grace") return "Planting is locked during grace. Extend now or harvest your remaining crops.";
  if (view.state.reservation.memberStatus === "departing") return "You can care for and harvest your own crops, but you cannot plant or work other members' crops.";
  if ((view.counts?.ready ?? 0) > 0) return "Ready crops keep their quality. Harvest your yellow-marked slots before starting another care round.";
  if ((view.counts?.critical ?? 0) > 0) return "Treat red-orange slots first. Critical conditions reduce quality and final yield.";
  if ((view.counts?.care ?? 0) > 0) return "Amber slots are in Watch. Complete the suggested care before they become critical.";
  if ((view.counts?.empty ?? 0) > 0) return "Ivory markers are empty slots available for planting.";
  return "All streamed crops are stable. Keep the next care round inside the green window.";
}

export function App({ initial }: { initial?: FieldHudView }) {
  const [view, setView] = useState<FieldHudView | null>(initial ?? null);
  const [tick, setTick] = useState(0);

  useEffect(() => {
    const receive = (event: MessageEvent<FieldHudMessage>) => {
      const message = event.data;
      if (!message || typeof message.type !== "string" || !message.type.startsWith("fieldHud:")) return;
      if (message.type === "fieldHud:hide") return setView(null);
      if (message.type === "fieldHud:mode") return setView((current) => current ? { ...current, expanded: message.payload?.expanded ?? current.expanded } : current);
      if (message.type === "fieldHud:show" && message.payload?.state) {
        setTick(0);
        return setView(message.payload as FieldHudView);
      }
      if (message.type === "fieldHud:update") {
        if (message.payload?.remainingSeconds != null) setTick(0);
        setView((current) => {
          if (!current) return message.payload?.state ? message.payload as FieldHudView : current;
          return { ...current, ...message.payload, state: message.payload?.state ?? current.state };
        });
      }
    };
    window.addEventListener("message", receive);
    return () => window.removeEventListener("message", receive);
  }, []);

  useEffect(() => {
    if (!view) return;
    const interval = window.setInterval(() => setTick((value) => value + 1), 1000);
    return () => window.clearInterval(interval);
  }, [view]);

  const timer = useMemo(() => duration(Math.max(0, (view?.remainingSeconds ?? 0) - tick)), [view?.remainingSeconds, tick]);
  if (!view) return null;
  const counts = view.counts ?? EMPTY_COUNTS;
  const restricted = !view.state.access.allowed;
  const departing = view.state.reservation.memberStatus === "departing";
  const grace = view.state.reservation.status === "grace";
  const status = view.sync === "unavailable" ? "Sync unavailable" : view.sync === "loading" ? "Syncing" : view.sync === "stale" || view.stale ? "Sync stale" : restricted ? "Restricted" : grace ? "Grace period" : departing ? "Departing" : "Active";
  const interactionLabel = restricted ? "Blocked" : departing ? "Own crops only" : grace ? "Care / harvest" : "Enabled";
  const occupied = Math.min(view.state.field.slotCount, counts.healthy + counts.care + counts.critical + counts.ready);

  return <main className={`field-hud-world position-${view.position}`}>
    <article className={`field-hud ${view.expanded ? "is-expanded" : "is-compact"}`} data-status={status.toLowerCase().replace(" ", "-")}>
      <header>
        <span className="brand-mark"><Grains size={24} weight="fill" /></span>
        <div><small>Field operations</small><h1>{view.state.field.name}</h1></div>
        <b>{view.state.field.sizeClass}{view.state.field.slotCount}</b>
      </header>
      <section className="status-line">
        <span className="status-pill"><i />{status}</span>
        <span><Clock size={14} />{view.state.reservation.status === "grace" ? "Grace ends" : "Rental"}</span>
        <strong>{timer}</strong>
      </section>
      <section className="next-action" data-kind={view.nextAction?.kind ?? "none"}>
        <div><small>Next priority</small><strong>{view.nextAction?.label ?? "Syncing Field"}</strong></div>
        {view.nextAction?.slotId ? <span><MapPin size={14} weight="fill" />{view.nextAction.rowId} · {view.nextAction.slotId}<em>{view.nextAction.distance?.toFixed(1)} m</em></span> : null}
      </section>

      {view.expanded ? <div className="expanded-content">
        <section className="occupancy">
          <div className="section-title"><span>Field condition</span><b>{view.streamedSlots ?? 0}/{view.state.field.slotCount} slots visible</b></div>
          <div className="occupancy-track"><i style={{ width: `${view.state.field.slotCount ? occupied / view.state.field.slotCount * 100 : 0}%` }} /></div>
          <div className="stats"><Stat tone="empty" value={counts.empty} label="Empty"/><Stat tone="healthy" value={counts.healthy} label="Healthy"/><Stat tone="care" value={counts.care} label="Need care"/><Stat tone="ready" value={counts.ready} label="Ready"/></div>
          {counts.critical > 0 ? <div className="critical-note"><Warning size={14} weight="fill"/>{counts.critical} critical slot{counts.critical === 1 ? "" : "s"}</div> : null}
        </section>
        <section className="crew">
          <span><UsersThree size={17}/><small>Role & co-op</small><strong>{view.state.reservation.role} · {view.state.reservation.memberCount}/4</strong></span>
          <span><Plant size={17}/><small>Your crops</small><strong>{view.state.reservation.ownCrops}</strong></span>
          <span className={restricted || departing || grace ? "is-restricted" : ""}>{restricted || departing || grace ? <ShieldWarning size={17}/> : <CheckCircle size={17}/>}<small>Interactions</small><strong>{interactionLabel}</strong></span>
        </section>
        <section className="cycle-guide"><div className="section-title"><span>Working cycle</span><b>Repeat while rented</b></div><ol>{GUIDE.map((step, index) => <li key={step} className={index === 1 ? "is-current" : ""}><i>{index + 1}</i><span>{step}</span></li>)}</ol></section>
        <section className="field-tip"><Leaf size={17} weight="fill"/><div><small>Field guide</small><p>{tip(view)}</p></div></section>
        <section className="legend" aria-label="Field marker legend"><span data-tone="empty">Empty</span><span data-tone="healthy">Stable</span><span data-tone="care">Care</span><span data-tone="critical">Urgent</span><span data-tone="ready">Ready</span><span data-tone="blocked">Blocked</span></section>
      </div> : null}
      <footer><span>{view.state.field.region ?? view.state.field.location}</span><kbd>C</kbd><strong>{view.expanded ? "Compact" : "Expand"}</strong><kbd>Z</kbd><strong>Hide</strong></footer>
    </article>
  </main>;
}
