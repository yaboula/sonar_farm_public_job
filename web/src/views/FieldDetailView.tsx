import { Clock, LockKey, MapPin, Plant } from "@phosphor-icons/react";
import { useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { DeepViewShell } from "../components/DeepViewShell";
import { FieldMap } from "../components/FieldMap";
import { StatePanel } from "../components/StatePanel";
import { useHubView } from "../hooks/useHubView";
import { useHub } from "../store/HubContext";
import type { FieldDetailData, RentPlan } from "../types";
import { rejectionMessage } from "../utils/rejectionMessage";

export function FieldDetailView() {
  const fieldId = useParams().fieldId ?? "";
  const navigate = useNavigate();
  const hub = useHub();
  const view = useHubView<FieldDetailData>({ kind: "fieldDetail", fieldId });
  const [selectedPlan, setSelectedPlan] = useState<RentPlan>();
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string>();
  const operationRef = useRef<string | undefined>(undefined);
  if (view.state !== "ready") return <StatePanel state={view.state} onAction={() => void view.reload()} />;
  if (!view.data) return <StatePanel state="empty" title="Field not found" body="This Field is not part of the public catalog." onAction={() => navigate("/fields")} />;

  const data = view.data;
  const participatingHere = data.reservation?.fieldId === fieldId;
  const canExtend = participatingHere && data.reservation?.isOwner === true;
  const participatingElsewhere = Boolean(data.reservation && !participatingHere);
  const canReserve = !data.reservation && data.field.available;
  const locked = data.progression.level < data.field.requiredLevel;

  const confirmPlan = async () => {
    if (!selectedPlan || (!canExtend && (!canReserve || locked))) return;
    operationRef.current ??= crypto.randomUUID();
    setBusy(true);
    const result = await hub.adapter.dispatch({ type: canExtend ? "field.extend" : "field.reserve", fieldId, hours: selectedPlan.hours, operationId: operationRef.current });
    setBusy(false);
    setNotice(result.message ?? (result.ok ? "Reservation updated." : rejectionMessage(result.reason, "Reservation rejected.")));
    if (result.ok) { operationRef.current = undefined; setSelectedPlan(undefined); await view.reload(); }
  };

  const statusLabel = participatingHere ? data.reservation?.status : data.field.available ? "available" : "reserved";
  const actionBar = <><div className="domain-action-summary"><span>{participatingHere ? canExtend ? "Active reservation" : "Co-op participation" : data.field.available ? "Field available" : "Currently reserved"}</span><p>{participatingHere ? `${data.reservation?.liveCrops ?? 0} live crops · ${data.reservation?.status}` : `Level ${data.field.requiredLevel} · ${data.field.slotCount} slots`}</p></div><div className="domain-action-group"><button className="domain-secondary-action" type="button" onClick={() => navigate("/fields")}>Back to Fields</button>{data.field.access ? <button className="domain-primary-action" type="button" onClick={() => void hub.adapter.dispatch({ type: "field.setRoute", fieldId })}><MapPin size={17} />Mark Route</button> : null}</div></>;

  return <DeepViewShell eyebrow="Public Field topology" title={data.field.name} subtitle={`${data.field.region} · Size ${data.field.sizeClass} · ${data.field.slotCount} authoritative planting slots`} backLabel="All public Fields" onBack={() => navigate("/fields")} status={<span className={`status-pill ${participatingHere ? data.reservation?.status : data.field.available ? "active" : "neutral"}`}>{statusLabel}</span>} actionBar={actionBar}>
    {notice ? <div className="domain-notice domain-notice--inline" role="status" aria-live="polite">{notice}</div> : null}
    <div className="field-detail-layout"><FieldMap field={data.field} /><aside className="rental-inspector"><span className="inspector-kicker">{canExtend ? "Extend rental" : participatingHere ? "Co-op access" : "Rental plans"}</span><Plant size={38} weight="thin" /><h2>{canExtend ? "Keep this Field" : participatingHere ? "Owner-managed Field" : "Reserve the complete Field"}</h2><p>{canExtend || canReserve ? "Prices include your personal level discount." : participatingHere ? "Only the reservation owner can extend this Field." : participatingElsewhere ? "Leave or finish your current Field before joining another." : "The current holder remains private."}</p><div className="inspector-rule" />{data.rentPlans.map((plan) => <button className="rental-plan" type="button" key={plan.hours} disabled={busy || locked || (!canExtend && !canReserve)} onClick={() => { operationRef.current = undefined; setSelectedPlan(plan); }}><span><Clock size={18} /><strong>{plan.hours} hours</strong><small>{plan.graceSurcharge ? "25% grace surcharge included" : "Real-time rental"}</small></span><b>${plan.price.toLocaleString()}</b></button>)}{locked ? <div className="physical-note is-warning"><LockKey size={18} /><span>Reach level {data.field.requiredLevel} to rent this size.</span></div> : null}{participatingElsewhere ? <div className="physical-note is-warning"><LockKey size={18} /><span>You already participate in another Field.</span></div> : null}{participatingHere && !canExtend ? <div className="physical-note is-warning"><LockKey size={18} /><span>Only the reservation owner can extend or release this Field.</span></div> : null}<small className="fine-print">Maximum accumulated expiry is 24 hours from now. Early release has no refund.</small></aside></div>
    {selectedPlan ? <ConfirmDialog eyebrow={canExtend ? "Rental extension" : "Public Field reservation"} title={`${canExtend ? "Extend" : "Reserve"} for ${selectedPlan.hours} hours?`} confirmLabel={canExtend ? "Extend Rental" : "Reserve Field"} pending={busy} onClose={() => setSelectedPlan(undefined)} onConfirm={() => void confirmPlan()}><div className="confirmation-facts"><div><span>Field</span><strong>{data.field.name}</strong></div><div><span>Duration</span><strong>{selectedPlan.hours} hours</strong></div><div><span>Bank charge</span><strong>${selectedPlan.price.toLocaleString()}</strong></div><div><span>Level discount</span><strong>{Math.round(data.progression.rentDiscount * 100)}%</strong></div></div>{selectedPlan.graceSurcharge ? <p>The displayed amount already includes the 25% grace surcharge.</p> : null}</ConfirmDialog> : null}
  </DeepViewShell>;
}
