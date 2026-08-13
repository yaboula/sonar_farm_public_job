import { ArrowRight, CheckCircle, Clock, Funnel, LockKey, MagnifyingGlass, MapPin, Plant } from "@phosphor-icons/react";
import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { FarmSelect } from "../components/FarmSelect";
import { HubScaffold } from "../components/HubScaffold";
import { StatePanel } from "../components/StatePanel";
import { useHubView } from "../hooks/useHubView";
import type { FieldsData, PublicField } from "../types";

const regionOptions = ["All", "Grapeseed", "Paleto"].map((value) => ({ value, label: value === "All" ? "All regions" : value }));
const statusOptions = [{ value: "all", label: "All Fields" }, { value: "available", label: "Available" }, { value: "reserved", label: "Reserved" }];

export function FieldsView() {
  const navigate = useNavigate();
  const view = useHubView<FieldsData>({ kind: "fieldsOverview" });
  const [region, setRegion] = useState("All");
  const [status, setStatus] = useState("all");
  const [query, setQuery] = useState("");
  const [selectedId, setSelectedId] = useState<string>();
  const data = view.data;
  const fields = useMemo(() => (data?.fields ?? []).filter((field) => {
    if (region !== "All" && field.region !== region) return false;
    if (status === "available" && !field.available) return false;
    if (status === "reserved" && field.available) return false;
    return `${field.name} ${field.location} ${field.sizeClass}`.toLowerCase().includes(query.toLowerCase());
  }), [data?.fields, query, region, status]);
  const selected = fields.find((field) => field.id === selectedId) ?? fields[0];

  if (view.state !== "ready") return <StatePanel state={view.state} onAction={() => void view.reload()} />;
  if (!data) return <StatePanel state="empty" />;

  const toolbar = <><div className="hub-tabs" aria-label="Field availability"><Funnel size={17} />{statusOptions.map((option) => <button type="button" className={status === option.value ? "is-selected" : ""} key={option.value} onClick={() => setStatus(option.value)}>{option.label}</button>)}</div><label className="search-control"><MagnifyingGlass size={18} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search Fields" /></label><FarmSelect label="Region" value={region} options={regionOptions} onChange={setRegion} /></>;
  const aside = selected ? <FieldInspector field={selected} level={data.progression.level} onOpen={() => navigate(`/fields/${selected.id}`)} /> : undefined;

  return <HubScaffold eyebrow="Public land rental" title="Fields" subtitle="Reserve one complete Field and farm only inside its authoritative topology." toolbar={toolbar} aside={aside}>
    <div className="fields-landing"><div><MapPin size={25} /><span><small>Your access</small><strong>{data.reservation ? data.reservation.fieldId.replaceAll("_", " ") : "No active reservation"}</strong></span></div><div><span>Level discount</span><strong>{Math.round(data.progression.rentDiscount * 100)}%</strong></div><div><span>Participation rule</span><strong>One Field at a time</strong></div></div>
    <div className="public-field-grid">{fields.length ? fields.map((field) => {
      const locked = data.progression.level < field.requiredLevel;
      return <button type="button" key={field.id} className={`public-field-card${selected?.id === field.id ? " is-selected" : ""}${!field.available ? " is-reserved" : ""}`} onClick={() => setSelectedId(field.id)} onDoubleClick={() => navigate(`/fields/${field.id}`)}>
        <div className="field-card-top"><span className="field-size">{field.sizeClass}{field.slotCount}</span><span className={`field-availability ${field.available ? "available" : "reserved"}`}>{field.available ? <CheckCircle size={15} /> : <Clock size={15} />}{field.available ? "Available" : "Reserved"}</span></div>
        <div className="field-card-title"><Plant size={31} weight="thin" /><div><h2>{field.name}</h2><p>{field.location}</p></div></div>
        <div className="field-card-rule" />
        <div className="field-card-meta"><span>{locked ? <><LockKey size={15} />Level {field.requiredLevel}</> : `${field.slotCount} planting slots`}</span><strong>From ${field.rentPlans[0]?.price.toLocaleString()}</strong></div>
      </button>;
    }) : <div className="inline-empty">No public Fields match these filters.</div>}</div>
  </HubScaffold>;
}

function FieldInspector({ field, level, onOpen }: { field: PublicField; level: number; onOpen: () => void }) {
  const locked = level < field.requiredLevel;
  return <div className="detail-inspector field-inspector"><span className="inspector-kicker">Selected Field</span><MapPin size={38} weight="thin" /><h2>{field.name}</h2><p>{field.location}</p><div className="inspector-rule" /><dl><div><dt>Region</dt><dd>{field.region}</dd></div><div><dt>Size</dt><dd>{field.sizeClass} · {field.slotCount} slots</dd></div><div><dt>Status</dt><dd>{field.available ? "Available" : "Reserved"}</dd></div><div><dt>Required level</dt><dd>{field.requiredLevel}</dd></div></dl><div className={`physical-note ${locked ? "is-warning" : ""}`}>{locked ? <LockKey size={18} /> : <CheckCircle size={18} />}<span>{locked ? `Reach level ${field.requiredLevel} to rent this Field.` : field.available ? "You can review rental plans now." : "Holder identity remains private."}</span></div><button className="inspector-action" type="button" onClick={onOpen}>Open Field Details<ArrowRight size={18} /></button></div>;
}
