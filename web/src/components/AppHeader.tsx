import { Plant } from "@phosphor-icons/react";
import { NavLink } from "react-router-dom";
import { useHub } from "../store/HubContext";
import type { HubRoute } from "../types";
const links: Array<{ id: HubRoute; label: string }> = [
  { id: "today", label: "Today" }, { id: "fields", label: "Fields" },
  { id: "market", label: "Market" }, { id: "sell", label: "Sell" },
];
export function AppHeader() {
  const hub = useHub();
  return <header className="app-header">
    <div className="brand-lockup"><Plant size={26} weight="duotone" /><div><strong>SONAR FARM</strong><span>PUBLIC JOB</span></div></div>
    <nav aria-label="Primary navigation">{links.filter(({ id }) => hub.routes.includes(id)).map(({ id, label }) =>
      <NavLink key={id} to={`/${id}`} className={({ isActive }) => isActive ? "nav-link is-active" : "nav-link"}>{label}</NavLink>)}</nav>
    <div className="player-summary"><span>LVL {hub.progression.level}</span><strong>{hub.actorName ?? "Farmer"}</strong><small>{hub.surface === "tablet" ? "Remote tablet" : `${hub.surface} counter`}</small></div>
  </header>;
}
