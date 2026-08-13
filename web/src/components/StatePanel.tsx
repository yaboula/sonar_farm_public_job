import { ArrowClockwise, CircleNotch, LockKey, Tray, WarningCircle, WifiSlash } from "@phosphor-icons/react";
import type { ViewState } from "../types";

const COPY: Record<Exclude<ViewState, "ready">, { title: string; body: string; action?: string; icon: typeof CircleNotch }> = {
  loading: { title: "Loading farm data...", body: "Checking your public farming records.", icon: CircleNotch },
  empty: { title: "Nothing to show", body: "There are no records for this view right now.", icon: Tray },
  blocked: { title: "Action temporarily blocked", body: "Finish the current farm action before starting another one.", action: "Try again", icon: LockKey },
  error: { title: "Farm data could not load", body: "The latest records are unavailable.", action: "Try again", icon: WarningCircle },
  restricted: { title: "Farmer access required", body: "You must be a farmer and on duty to use this Hub.", icon: LockKey },
  unavailable: { title: "Farm service is unavailable", body: "No changes were submitted. Try again when service returns.", action: "Try again", icon: WifiSlash },
};

interface StatePanelProps {
  state: Exclude<ViewState, "ready">;
  onAction?: () => void;
  title?: string;
  body?: string;
  actionLabel?: string;
}

export function StatePanel({ state, onAction, title, body, actionLabel }: StatePanelProps) {
  const content = COPY[state];
  const Icon = content.icon;
  return (
    <section className={`state-panel state-panel--${state}`} role={state === "error" ? "alert" : undefined}>
      <Icon className={state === "loading" ? "spin" : ""} size={62} weight="thin" />
      <span className="state-kicker">{state}</span>
      <h1>{title ?? content.title}</h1>
      <p>{body ?? content.body}</p>
      {content.action ? <button type="button" className="secondary-button" onClick={onAction}>{actionLabel ?? content.action}<ArrowClockwise size={18} /></button> : null}
      {state === "loading" ? <div className="skeleton-stack" aria-hidden="true"><i /><i /><i /></div> : null}
    </section>
  );
}
