import { MapPin } from "@phosphor-icons/react";
import { Link } from "react-router-dom";
import { ViewFrame } from "../components/ViewFrame";
import { useHubView } from "../hooks/useHubView";
import type { FieldsData } from "../types";
const occupiedUntil = (timestamp?: number) => timestamp
  ? `Reserved until ${new Date(timestamp * 1000).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}`
  : "Reserved";
export function FieldsView() {
  const view = useHubView<FieldsData>({ kind: "fieldsOverview" }); const data = view.data;
  return <ViewFrame title="Public Fields" eyebrow="RESERVE A COMPLETE FIELD" state={view.state} error={view.error}>{data && <>
    <div className="notice">Prices include your {Math.round(data.progression.rentDiscount * 100)}% level discount. A player can join only one reservation at a time.</div>
    <div className="field-grid">{data.fields.map(field => <Link to={`/fields/${field.id}`} className={`field-card ${!field.available ? "occupied" : ""}`} key={field.id}>
      <div><span className="size-badge">{field.sizeClass}{field.slotCount}</span><span className={`availability ${field.available ? "free" : "busy"}`}>{field.available ? "AVAILABLE" : "RESERVED"}</span></div>
      <h2>{field.name}</h2><p><MapPin size={16} /> {field.location}</p><footer><span>From</span><strong>${field.rentPlans[0]?.price.toLocaleString()}</strong><small>{!field.available ? occupiedUntil(field.expiresAt) : field.requiredLevel > data.progression.level ? `Requires level ${field.requiredLevel}` : "Open details"}</small></footer>
    </Link>)}</div>
  </>}</ViewFrame>;
}
