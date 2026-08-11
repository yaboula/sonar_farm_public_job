import type { PropsWithChildren } from "react";
import type { ViewState } from "../types";
export function ViewFrame({ title, eyebrow, state = "ready", error, children }:
  PropsWithChildren<{ title: string; eyebrow: string; state?: ViewState; error?: string }>) {
  return <section className="view"><header className="view-title"><div><span>{eyebrow}</span><h1>{title}</h1></div></header>
    {state === "loading" ? <div className="state-card">Loading live data…</div>
      : state === "restricted" ? <div className="state-card danger">Farmer job and on-duty status are required.</div>
      : state === "error" || state === "unavailable" ? <div className="state-card danger">{error ?? "This view is unavailable."}</div>
      : children}</section>;
}
