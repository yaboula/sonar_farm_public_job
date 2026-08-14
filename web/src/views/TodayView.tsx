import { ArrowRight, Clock, Coins, MapPin, Package, Plant, UsersThree } from "@phosphor-icons/react";
import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { FarmSelect } from "../components/FarmSelect";
import { StatePanel } from "../components/StatePanel";
import { useHubView } from "../hooks/useHubView";
import { useHub } from "../store/HubContext";
import type { TodayData } from "../types";
import { formatDateTime, formatRemaining, money } from "../utils/format";
import { rejectionMessage } from "../utils/rejectionMessage";

export function TodayView() {
  const hub = useHub();
  const navigate = useNavigate();
  const view = useHubView<TodayData>({ kind: "hub", route: "today" });
  const [clock, setClock] = useState(() => Math.floor(Date.now() / 1000));
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string>();
  const [releaseOpen, setReleaseOpen] = useState(false);
  const [candidates, setCandidates] = useState<Array<{ source: number; name: string }>>([]);
  const [candidateSource, setCandidateSource] = useState("");
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
    const next = response.data ?? [];
    setCandidates(next);
    setCandidateSource(next[0] ? String(next[0].source) : "");
    if (!next.length) setNotice("No on-duty farmers are within 15 metres.");
  };

  const setFieldRoute = async () => {
    if (!reservation) return;
    const result = await hub.adapter.dispatch({ type: "field.setRoute", fieldId: reservation.fieldId });
    setNotice(result.message ?? (result.ok ? "Route marked to your Field." : rejectionMessage(result.reason, "Route unavailable.")));
  };

  const sellPreview = data.sellableGroups.reduce((sum, group) => sum + group.quantity * group.unitPrice, 0);
  const activeMembers = reservation?.members.filter((member) => member.status !== "released") ?? [];
  return (
    <section className="today-view">
      <div className="today-image" aria-hidden="true" />
      <div className="today-vignette" aria-hidden="true" />
      <header className="today-intro"><span>Personal farming</span><h1>Today</h1><p>What needs your attention now?</p></header>
      {notice ? <div className="domain-notice domain-notice--today" role="status" aria-live="polite">{notice}</div> : null}
      <article className="assignment-hero publicjob-hero">
        <span className={`status-pill ${reservation?.status ?? "neutral"}`}><Clock size={18} />{reservation ? reservation.status : "Ready to farm"}</span>
        {reservation ? <>
          <div className="assignment-main"><Plant className="assignment-icon" size={76} weight="thin" /><div className="assignment-copy"><span>Your reserved Field</span><h2>{reservation.fieldId.replaceAll("_", " ")}</h2><p>{reservation.liveCrops} live crops <b>·</b> {reservation.ownCrops} yours</p><strong>{formatRemaining(reservation.status === "grace" ? reservation.graceUntil : reservation.expiresAt, clock)} remaining</strong><small className="assignment-expiry">{reservation.status === "grace" ? "Grace ends" : "Rental ends"} {formatDateTime(reservation.status === "grace" ? reservation.graceUntil : reservation.expiresAt)}</small><div className="reservation-track"><i className={reservation.status} /></div></div></div>
          <div className="related-order"><Plant size={23} /><span>{data.ownCropSummary?.ready ?? 0} ready · {data.ownCropSummary?.needsAttention ?? 0} need attention</span><i>·</i><UsersThree size={21} /><span>{activeMembers.length} farmers</span></div>
          <div className="assignment-actions"><button className="secondary-icon-button" type="button" onClick={() => void setFieldRoute()} aria-label="Mark route to your Field"><MapPin size={21} /></button><button className="primary-button" type="button" onClick={() => navigate(`/fields/${reservation.fieldId}`)}>{reservation.status === "grace" ? "Extend During Grace" : "Open Field Control"}<ArrowRight size={24} /></button></div>
        </> : <>
          <div className="assignment-main"><Plant className="assignment-icon" size={76} weight="thin" /><div className="assignment-copy"><span>Public Fields available</span><h2>Reserve your next Field</h2><p>Choose a complete S, M or L Field in Grapeseed or Paleto.</p><strong>Rental time continues while offline</strong></div></div>
          <div className="related-order"><Clock size={23} /><span>1, 3, 6 or 8 hour plans</span><i>·</i><span>Your level discount applies automatically</span></div>
          <button className="primary-button" type="button" onClick={() => navigate("/fields")}>Browse Public Fields<ArrowRight size={24} /></button>
        </>}
      </article>
      <aside className="priority-rail" aria-label="Personal farm priorities">
        <article className="progress-priority"><div className="priority-heading"><span>Farmer progression</span><strong>LVL {data.progression.level}</strong></div><div className="xp-ring"><span>{Math.round(xpProgress)}%</span></div><p>{data.progression.xp.toLocaleString()} XP</p><small>{data.nextUnlock ? `Next: ${data.nextUnlock.label} at level ${data.nextUnlock.level}` : "All perks unlocked"}</small><div className="progress-track"><i style={{ width: `${xpProgress}%` }} /></div></article>
        <article className="priority-item compact"><span className="priority-number is-first">1</span><Package className="priority-icon" size={38} weight="thin" /><div className="priority-copy"><h3>Market stock</h3><strong>{data.marketStock.plus ?? 0} Plus · {data.marketStock.pro ?? 0} Pro</strong><p>Global supply available now</p><Link to="/market">Open Market<ArrowRight size={16} /></Link></div></article>
        <article className="priority-item compact"><span className="priority-number">2</span><Coins className="priority-icon" size={38} weight="thin" /><div className="priority-copy"><h3>Ready to sell</h3><strong>{data.sellableGroups.reduce((sum, group) => sum + group.quantity, 0)} items</strong><p>Preview {money(sellPreview)} before bonus</p><Link to="/sell">Review Produce<ArrowRight size={16} /></Link></div></article>
      </aside>
      {reservation ? <section className="today-coop-strip"><div><span>Co-op roster</span><strong>{activeMembers.length} / 4 participants</strong></div><div className="today-member-list">{reservation.members.map((member) => <div key={member.identifier}><span>{member.display_name}</span><small>{member.role} · {member.status}</small>{reservation.isOwner && member.role === "guest" && member.status === "active" ? <button disabled={busy} onClick={() => void act({ type: "coop.revoke", identifier: member.identifier })}>Revoke</button> : null}</div>)}</div>{reservation.isOwner ? <div className="today-coop-actions">{candidates.length ? <><FarmSelect label="Nearby farmer" value={candidateSource} options={candidates.map((candidate) => ({ value: String(candidate.source), label: candidate.name }))} onChange={setCandidateSource} /><button disabled={busy || !candidateSource} onClick={() => void act({ type: "coop.invite", targetSource: Number(candidateSource) })}>Send 60s invite</button></> : <button disabled={busy || activeMembers.length >= 4} onClick={() => void loadCandidates()}>Find nearby farmers</button>}<button className="danger-link" disabled={busy} onClick={() => setReleaseOpen(true)}>Release Field</button></div> : <button className="secondary-button" disabled={busy} onClick={() => void act({ type: "coop.leave" })}>Leave co-op</button>}</section> : <section className="today-onboarding" aria-label="Public farming quick start"><div><span>1</span><strong>Reserve a Field</strong><small>Select one complete public topology.</small></div><i /><div><span>2</span><strong>Plant and care</strong><small>Use personal materials inside your Field.</small></div><i /><div><span>3</span><strong>Harvest and Sell</strong><small>Keep ownership and quality value.</small></div></section>}
      {releaseOpen ? <ConfirmDialog eyebrow="Reservation control" title="Release this Field now?" confirmLabel="Release Field" tone="danger-confirm" pending={busy} onClose={() => setReleaseOpen(false)} onConfirm={() => void act({ type: "field.release", confirmed: true }).then((ok) => { if (ok) setReleaseOpen(false); })}><p>All live crops will be destroyed immediately. There is no refund and every participant receives the same-Field cooldown.</p></ConfirmDialog> : null}
    </section>
  );
}
