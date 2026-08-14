import { Clock, LockKey, MapPin, Plant, Wallet } from "@phosphor-icons/react";
import { useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { ConfirmDialog } from "../components/ConfirmDialog";
import { DeepViewShell } from "../components/DeepViewShell";
import { FieldMap } from "../components/FieldMap";
import { StatePanel } from "../components/StatePanel";
import { useHubView } from "../hooks/useHubView";
import { useHub } from "../store/HubContext";
import type { FieldDetailData, RentPlan } from "../types";
import { formatDateTime, formatRemaining, money } from "../utils/format";
import { rejectionMessage } from "../utils/rejectionMessage";

const rentalDuration = (hours: RentPlan["hours"]) => `${hours} ${hours === 1 ? "hour" : "hours"}`;

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
  const timerTarget = participatingHere && data.reservation?.status === "grace" ? data.reservation.graceUntil : participatingHere ? data.reservation?.expiresAt : data.field.expiresAt;

  const confirmPlan = async () => {
    if (!selectedPlan || selectedPlan.available === false || selectedPlan.price > data.bankBalance || (!canExtend && (!canReserve || locked))) return;
    operationRef.current ??= crypto.randomUUID();
    setBusy(true);
    const result = await hub.adapter.dispatch({ type: canExtend ? "field.extend" : "field.reserve", fieldId, hours: selectedPlan.hours, operationId: operationRef.current });
    setBusy(false);
    setNotice(result.message ?? (result.ok ? "Reservation updated." : rejectionMessage(result.reason, "Reservation rejected.")));
    if (result.ok) { operationRef.current = undefined; setSelectedPlan(undefined); await view.reload(); }
  };

  const statusLabel = participatingHere ? data.reservation?.status : data.field.available ? "available" : "reserved";
  const actionBar = <><div className="domain-action-summary"><span>{participatingHere ? canExtend ? "Your active reservation" : "Co-op participation" : data.field.available ? "Field available" : "Currently reserved"}</span><p>{participatingHere ? `${formatRemaining(timerTarget)} remaining · ${data.reservation?.liveCrops ?? 0} live crops` : data.field.available ? `Level ${data.field.requiredLevel} · ${data.field.slotCount} slots` : `Expected availability ${formatDateTime(data.field.expiresAt)}`}</p></div><div className="domain-action-group"><button className="domain-secondary-action" type="button" onClick={() => navigate("/fields")}>Back to Fields</button>{data.field.access ? <button className="domain-primary-action" type="button" onClick={() => void hub.adapter.dispatch({ type: "field.setRoute", fieldId })}><MapPin size={17} />Mark Route</button> : null}</div></>;

  return <DeepViewShell eyebrow="Public Field topology" title={data.field.name} subtitle={`${data.field.region} · Size ${data.field.sizeClass} · ${data.field.slotCount} authoritative planting slots`} backLabel="All public Fields" onBack={() => navigate("/fields")} status={<span className={`status-pill ${participatingHere ? data.reservation?.status : data.field.available ? "active" : "neutral"}`}>{statusLabel}</span>} actionBar={actionBar}>
    {notice ? <div className="domain-notice domain-notice--inline" role="status" aria-live="polite">{notice}</div> : null}
    <div className="field-detail-layout"><div className="field-map-column"><FieldMap field={data.field} /><div className="field-crop-strip"><span>Allowed crops</span>{data.field.allowedCrops.map((crop) => <b key={crop}>{crop}</b>)}</div></div><aside className="rental-inspector"><span className="inspector-kicker">{canExtend ? "Extend rental" : participatingHere ? "Co-op access" : "Rental plans"}</span><Plant size={38} weight="thin" /><h2>{canExtend ? "Keep this Field" : participatingHere ? "Owner-managed Field" : "Reserve the complete Field"}</h2><p>{canExtend || canReserve ? "Prices include your personal level discount." : participatingHere ? "Only the reservation owner can extend this Field." : participatingElsewhere ? "Leave or finish your current Field before joining another." : "The current holder remains private."}</p>{timerTarget ? <div className={`rental-clock ${data.reservation?.status === "grace" ? "is-grace" : ""}`}><Clock size={18} /><span><small>{data.reservation?.status === "grace" ? "Grace deadline" : participatingHere ? "Current expiry" : "Expected availability"}</small><strong>{formatDateTime(timerTarget)}</strong></span></div> : null}<div className="inspector-rule" />{data.rentPlans.map((plan) => <button className="rental-plan" type="button" key={plan.hours} disabled={busy || locked || plan.available === false || (!canExtend && !canReserve)} onClick={() => { operationRef.current = undefined; setSelectedPlan(plan); }}><span><Clock size={18} /><strong>{rentalDuration(plan.hours)}</strong><small>{plan.available === false ? "Would exceed the 8h limit" : plan.graceSurcharge ? "25% grace surcharge included" : "Real-time rental"}</small></span><b>{money(plan.price)}</b></button>)}<div className="rental-bank"><Wallet size={17} /><span>Personal bank</span><strong>{money(data.bankBalance)}</strong></div>{locked ? <div className="physical-note is-warning"><LockKey size={18} /><span>Reach level {data.field.requiredLevel} to rent this size.</span></div> : null}{participatingElsewhere ? <div className="physical-note is-warning"><LockKey size={18} /><span>You already participate in another Field.</span></div> : null}{participatingHere && !canExtend ? <div className="physical-note is-warning"><LockKey size={18} /><span>Only the reservation owner can extend or release this Field.</span></div> : null}<small className="fine-print">Maximum accumulated expiry is 8 hours from now. Early release has no refund.</small></aside></div>
    {selectedPlan ? <ConfirmDialog eyebrow={canExtend ? "Rental extension" : "Public Field reservation"} title={`${canExtend ? "Extend" : "Reserve"} for ${rentalDuration(selectedPlan.hours)}?`} confirmLabel={canExtend ? "Extend Rental" : "Reserve Field"} pending={busy} confirmDisabled={selectedPlan.price > data.bankBalance || selectedPlan.available === false} onClose={() => setSelectedPlan(undefined)} onConfirm={() => void confirmPlan()}><div className="confirmation-facts"><div><span>Field</span><strong>{data.field.name}</strong></div><div><span>Duration</span><strong>{rentalDuration(selectedPlan.hours)}</strong></div><div><span>New expiry</span><strong>{formatDateTime(selectedPlan.resultingExpiresAt)}</strong></div><div><span>Bank charge</span><strong>{money(selectedPlan.price)}</strong></div><div><span>Bank after</span><strong>{money(data.bankBalance - selectedPlan.price)}</strong></div><div><span>Level discount</span><strong>{Math.round(data.progression.rentDiscount * 100)}%</strong></div></div>{selectedPlan.price > data.bankBalance ? <p className="validation-warning">Your personal bank balance is too low for this plan.</p> : null}{selectedPlan.available === false ? <p className="validation-warning">This extension would exceed the maximum remaining time.</p> : null}{selectedPlan.graceSurcharge ? <p>The displayed amount already includes the 25% grace surcharge.</p> : null}</ConfirmDialog> : null}
  </DeepViewShell>;
}
