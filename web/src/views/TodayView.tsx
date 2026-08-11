import { useEffect, useState } from "react";
import { ViewFrame } from "../components/ViewFrame";
import { useHubView } from "../hooks/useHubView";
import { useHub } from "../store/HubContext";
import type { TodayData } from "../types";

const money = (value: number) => `$${value.toLocaleString("en-US")}`;
const remaining = (timestamp: number | undefined, now: number) => {
  if (!timestamp) return "";
  const seconds = Math.max(0, timestamp - now);
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.ceil((seconds % 3600) / 60);
  return hours > 0 ? `${hours}h ${minutes}m remaining` : `${minutes}m remaining`;
};

export function TodayView() {
  const { adapter } = useHub();
  const view = useHubView<TodayData>({ kind: "hub", route: "today" });
  const [busy, setBusy] = useState(false);
  const [clock, setClock] = useState(() => Math.floor(Date.now() / 1000));
  const [candidates, setCandidates] = useState<Array<{ source: number; name: string }>>([]);
  const data = view.data;
  useEffect(() => {
    const timer = window.setInterval(() => setClock(Math.floor(Date.now() / 1000)), 30_000);
    return () => window.clearInterval(timer);
  }, []);
  const act = async (intent: Record<string, unknown>) => {
    setBusy(true);
    await adapter.dispatch(intent);
    setBusy(false);
    await view.reload();
  };
  const findCandidates = async () => {
    const response = await adapter.load<Array<{ source: number; name: string }>>({ kind: "inviteCandidates" });
    setCandidates(response.data ?? []);
  };

  return <ViewFrame title="Today" eyebrow="PERSONAL FARMING" state={view.state} error={view.error}>{data && <>
    <div className="metric-grid">
      <article className="hero-card"><span>FARMER LEVEL</span><strong>{data.progression.level}<small>/20</small></strong>
        <div className="progress"><i style={{ width: `${Math.min(100, (data.progression.xp - data.progression.levelStartXp) / Math.max(1, data.progression.nextLevelXp - data.progression.levelStartXp) * 100)}%` }} /></div>
        <p>{data.progression.xp.toLocaleString()} XP &middot; {data.nextUnlock ? `Next: ${data.nextUnlock.label} at L${data.nextUnlock.level}` : "All perks unlocked"}</p></article>
      <article className="metric"><span>YOUR CROPS</span><strong>{data.ownCrops}</strong><p>Only you can harvest them</p></article>
      <article className="metric"><span>SELL BONUS</span><strong>+{Math.round(data.progression.sellBonus * 100)}%</strong><p>Applied after quality pricing</p></article>
      <article className="metric"><span>MARKET STOCK</span><strong>{data.marketStock.plus ?? 0}<small> PLUS</small></strong><p>{data.marketStock.pro ?? 0} Pro units available</p></article>
    </div>
    <div className="split-grid"><article className="panel"><h2>Current Field</h2>{data.reservation ? <>
      <div className={`status-pill ${data.reservation.status}`}>{data.reservation.status}</div>
      <h3>{data.reservation.fieldId.replaceAll("_", " ")}</h3>
      <p>{remaining(data.reservation.status === "grace" ? data.reservation.graceUntil : data.reservation.expiresAt, clock)}</p>
      <p>{data.reservation.liveCrops} live crops &middot; {data.reservation.ownCrops} yours</p>
      <div className="member-list">{data.reservation.members.map(member => <div key={member.identifier}><span>{member.display_name}</span><small>{member.role} &middot; {member.status}</small>
        {data.reservation?.isOwner && member.role === "guest" && member.status === "active" ? <button disabled={busy} onClick={() => void act({ type: "coop.revoke", identifier: member.identifier })}>Revoke</button> : null}</div>)}</div>
      {data.reservation.isOwner ? <><button disabled={busy} onClick={() => void findCandidates()}>Invite nearby farmer</button>
        {candidates.map(candidate => <button key={candidate.source} disabled={busy} onClick={() => void act({ type: "coop.invite", targetSource: candidate.source })}>{candidate.name}</button>)}
        <button className="danger-button" disabled={busy} onClick={() => confirm("Release now? All live crops will be destroyed and there is no refund.") && void act({ type: "field.release", confirmed: true })}>Release Field</button></>
        : <button disabled={busy} onClick={() => void act({ type: "coop.leave" })}>Leave co-op</button>}
    </> : <div className="empty"><strong>No Field reserved</strong><p>Choose an available public Field to start farming.</p></div>}</article>
    <article className="panel"><h2>Ready to sell</h2>{data.sellableGroups.length ? data.sellableGroups.map(group => <div className="row" key={group.key}><span>{group.cropType} &middot; {group.tier}</span><strong>{group.quantity} &times; {money(group.unitPrice)}</strong></div>) : <div className="empty">No eligible produce in inventory.</div>}</article></div>
  </>}</ViewFrame>;
}
