import { Plant } from "@phosphor-icons/react";
import { NavLink } from "react-router-dom";
import { useHub } from "../store/HubContext";
import type { HubRoute } from "../types";

const NAVIGATION: Array<{ id: HubRoute; label: string }> = [
  { id: "today", label: "Today" },
  { id: "fields", label: "Fields" },
  { id: "market", label: "Market" },
  { id: "sell", label: "Sell" },
];

export function AppHeader() {
  const hub = useHub();
  const levelSpan = Math.max(1, hub.progression.nextLevelXp - hub.progression.levelStartXp);
  const progress = hub.progression.level >= hub.progression.maxLevel
    ? 100
    : Math.max(0, Math.min(100, ((hub.progression.xp - hub.progression.levelStartXp) / levelSpan) * 100));
  const surfaceLabel = hub.surface === "tablet"
    ? "Farm Tablet"
    : hub.surface === "market" ? "Market Terminal" : "Sell Counter";

  return (
    <header className="app-header">
      <div className="brand-lockup" aria-label="Sonar Farm Public Job">
        <Plant size={27} weight="regular" />
        <span>Sonar Farm</span>
      </div>
      <div className="header-divider" />
      <span className="surface-label">{surfaceLabel}</span>
      <div className="context-separator" />
      <span className="role-label">Farmer</span>
      <nav className="primary-nav" aria-label="Primary navigation">
        {NAVIGATION.filter(({ id }) => hub.routes.includes(id)).map(({ id, label }) => (
          <NavLink key={id} to={`/${id}`} className={({ isActive }) => isActive ? "nav-link is-active" : "nav-link"}>
            {label}
          </NavLink>
        ))}
      </nav>
      <div className="player-progress" aria-label={`Level ${hub.progression.level}, ${hub.progression.xp} XP`}>
        <div className="player-progress-copy">
          <span>LVL {hub.progression.level}</span>
          <strong>{hub.actorName ?? "Farmer"}</strong>
        </div>
        <div className="header-xp-track"><i style={{ width: `${progress}%` }} /></div>
      </div>
    </header>
  );
}
