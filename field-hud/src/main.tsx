import "@fontsource/barlow-condensed/latin-500.css";
import "@fontsource/barlow-condensed/latin-600.css";
import "@fontsource/barlow-condensed/latin-700.css";
import "@fontsource/source-sans-3/latin-400.css";
import "@fontsource/source-sans-3/latin-600.css";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";
import { fieldHudFixture } from "./fixture";
import "./styles.css";
const root = createRoot(document.getElementById("root")!);
if (import.meta.env.DEV) {
  const fixture = fieldHudFixture();
  const params = new URLSearchParams(window.location.search);
  if (params.get("position") === "top-left") fixture.position = "top-left";
  if (params.get("mode") === "compact") fixture.expanded = false;
  if (params.get("state") === "restricted") {
    fixture.state.access = { job: "farmer", onDuty: false, allowed: false, reason: "duty_required" };
    fixture.counts = { empty: 0, healthy: 0, care: 0, critical: 0, ready: 0, blocked: 24, own: 11 };
    fixture.nextAction = { label: "Go on duty" };
  } else if (params.get("state") === "grace") {
    fixture.state.reservation.status = "grace";
    fixture.state.reservation.graceUntil = fixture.serverNow! + 612;
    fixture.remainingSeconds = 612;
    fixture.counts = { ...fixture.counts!, empty: 0, blocked: 6 };
    fixture.nextAction = { label: "Extend or finish harvesting", urgent: true };
  } else if (params.get("state") === "stale") fixture.sync = "stale";
  let expanded = fixture.expanded;
  window.addEventListener("keydown", (event) => {
    if (event.code === "KeyC") {
      expanded = !expanded;
      window.postMessage({ type: "fieldHud:mode", payload: { expanded } }, "*");
    }
  });
  root.render(<StrictMode><App initial={fixture}/></StrictMode>);
} else root.render(<StrictMode><App/></StrictMode>);
