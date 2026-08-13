import { ArrowRight, Clock, Coins, Package, Plant, UsersThree } from "@phosphor-icons/react";
import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { StatePanel } from "../components/StatePanel";
import { useHubView } from "../hooks/useHubView";
import { useHub } from "../store/HubContext";
import { rejectionMessage } from "../utils/rejectionMessage";
import type { TodayData } from "../types";

const money = (value: number) => `$${value.toLocaleString("en-US")}`;
function remaining(timestamp: number | undefined, now: number) {
  if (!timestamp) return "No active timer";
  const seconds = Math.max(0, timestamp - now);
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.ceil((seconds % 3600) / 60);
  return hours ? `${hours}h ${minutes}m remaining` : `${minutes}m remaining`;
}

export function TodayView() {
  const hub = useHub();
  const navigate = useNavigate();
  const view = useHubView<TodayData>({ kind: "hub", route: "today" });
  const [clock, setClock] = useState(() => Math.floor(Date.now() / 1000));
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string>();
  const [releaseOpen, setReleaseOpen] = useState(false);
  const [candidates, setCandidates] = useState<Array<{ source: number; name: string }>>([]);
  useEffect(() => {
    const timer = window.setInterval(() => setClock(Math.floor(Date.now() / 1000)), 30_000);
    return () => window.clearInterval(timer);
  }, []);

  if (view.state !== "ready") return <StatePanel state={view.state} onAction={() => void view.reload()} />;
  if (!view.data) return <StatePanel state="empty" />;
  const data = view.data;
  const reservation = data.reservation;
  const levelSpan = Math.max(1, data.progression.nextLevelXp - data.progression.levelStartXp);
  const xpProgress = data.progression.level >= data.progression.maxLevel ? 100 : Math.max(0, Math.min(100, ((data.progression.xp - data.progression.levelStartXp) / levelSpan) * 100));

  const act = async (intent: Record<string, unknown>) => {
    setBusy(true);
    const result = await hub.adapter.dispatch(intent);
    setBusy(false);
    setNotice(result.message ?? (result.ok ? "Farm record updated." : rejectionMessage(result.reason, "Action rejected.")));
    if (result.ok) await view.reload();
    return result.ok;
  };

  const loadCandidates = async () => {
    const response = await hub.adapter.load<Array<{ source: number; name: string }>>({ kind: "inviteCandidates" });
    setCandidates(response.data ?? []);
  };

  const sellPreview = data.sellableGroups.reduce((sum, group) => sum + group.quantity * group.unitPrice, 0);
  return (
    <section className="today-view">
      <div className="today-image" aria-hidden="true" />
      <div className="today-vignette" aria-hidden="true" />
      <header className="today-intro"><span>Personal farming</span><h1>Today</h1><p>What needs your attention now?</p></header>
      {notice ? <div className="domain-notice domain-notice--today" role="status" aria-live="polite">{notice}</div> : null}
      <article className="assignment-hero publicjob-hero">
        <span className={`status-pill ${reservation?.status ?? "neutral"}`}><Clock size={18} />{reservation ? reservation.status : "Ready to farm"}</span>
        {reservation ? <>
          <div className="assignment-main"><Plant className="assignment-icon" size={76} weight="thin" /><div className="assignment-copy"><span>Your reserved field</span><h2>{reservation.fieldId.replaceAll("_", " ")}</h2><p>{reservation.liveCrops} live crops <b>·</b> {reservation.ownCrops} yours</p><strong>{remaining(reservation.status === "grace" ? reservation.graceUntil : reservation.expiresAt, clock)}</strong><div className="reservation-track"><i className={reservation.status} /></div></div></div>
          <div className="related-order"><UsersThree size={23} /><span>{reservation.members.filter((member) => member.status !== "released").length} farmers participating</span><i>·</i><span>{reservation.isOwner ? "You manage this reservation" : "Co-op member"}</span></div>
          <button className="primary-button" type="button" onClick={() => navigate(`/fields/${reservation.fieldId}`)}>Open Field Control<ArrowRight size={24} /></button>
        </> : <>
          <div className="assignment-main"><Plant className="assignment-icon" size={76} weight="thin" /><div className="assignment-copy"><span>Public fields available</span><h2>Reserve your next field</h2><p>Choose a complete S, M or L field in Grapeseed or Paleto.</p><strong>Rental time continues while offline</strong></div></div>
          <div className="related-order"><Clock size={23} /><span>6, 12 or 24 hour plans</span><i>·</i><span>Your level discount applies automatically</span></div>
          <button className="primary-button" type="button" onClick={() => navigate("/fields")}>Browse Public Fields<ArrowRight size={24} /></button>
        </>}
      </article>
      <aside className="priority-rail" aria-label="Personal farm priorities">
        <article className="progress-priority"><div className="priority-heading"><span>Farmer progression</span><strong>LVL {data.progression.level}</strong></div><div className="xp-ring"><span>{Math.round(xpProgress)}%</span></div><p>{data.progression.xp.toLocaleString()} XP</p><small>{data.nextUnlock ? `Next: ${data.nextUnlock.label} at level ${data.nextUnlock.level}` : "All perks unlocked"}</small><div className="progress-track"><i style={{ width: `${xpProgress}%` }} /></div></article>
        <article className="priority-item compact"><span className="priority-number is-first">1</span><Package className="priority-icon" size={38} weight="thin" /><div className="priority-copy"><h3>Market stock</h3><strong>{data.marketStock.plus ?? 0} Plus · {data.marketStock.pro ?? 0} Pro</strong><p>Global supply available now</p><Link to="/market">Open Market<ArrowRight size={16} /></Link></div></article>
        <article className="priority-item compact"><span className="priority-number">2</span><Coins className="priority-icon" size={38} weight="thin" /><div className="priority-copy"><h3>Ready to sell</h3><strong>{data.sellableGroups.reduce((sum, group) => sum + group.quantity, 0)} items</strong><p>Preview {money(sellPreview)} before bonus</p><Link to="/sell">Review Produce<ArrowRight size={16} /></Link></div></article>
      </aside>
      {reservation ? <section className="today-coop-strip"><div><span>Co-op roster</span><strong>{reservation.members.length} / 4 participants</strong></div><div className="today-member-list">{reservation.members.map((member) => <div key={member.identifier}><span>{member.display_name}</span><small>{member.role} · {member.status}</small>{reservation.isOwner && member.role === "guest" && member.status === "active" ? <button disabled={busy} onClick={() => void act({ type: "coop.revoke", identifier: member.identifier })}>Revoke</button> : null}</div>)}</div>{reservation.isOwner ? <div className="today-coop-actions"><button disabled={busy} onClick={() => void loadCandidates()}>Find nearby farmers</button>{candidates.map((candidate) => <button key={candidate.source} disabled={busy} onClick={() => void act({ type: "coop.invite", targetSource: candidate.source })}>Invite {candidate.name}</button>)}<button className="danger-link" disabled={busy} onClick={() => setReleaseOpen(true)}>Release field</button></div> : <button className="secondary-button" disabled={busy} onClick={() => void act({ type: "coop.leave" })}>Leave co-op</button>}</section> : null}
      {releaseOpen ? <ConfirmDialog eyebrow="Reservation control" title="Release this Field now?" confirmLabel="Release Field" tone="danger-confirm" pending={busy} onClose={() => setReleaseOpen(false)} onConfirm={() => void act({ type: "field.release", confirmed: true }).then((ok) => { if (ok) setReleaseOpen(false); })}><p>All live crops will be destroyed immediately. There is no refund and every participant receives the same-field cooldown.</p></ConfirmDialog> : null}
    </section>
  );
}
