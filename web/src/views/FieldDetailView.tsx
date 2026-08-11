import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ViewFrame } from "../components/ViewFrame";
import { useHubView } from "../hooks/useHubView";
import { useHub } from "../store/HubContext";
import type { Progression, PublicField, RentPlan, Reservation } from "../types";

interface Detail {
  field: PublicField & { allowedCrops: string[]; slots?: unknown[] };
  reservation?: Reservation;
  progression: Progression;
  rentPlans: RentPlan[];
}

export function FieldDetailView() {
  const fieldId = useParams().fieldId ?? "";
  const { adapter } = useHub();
  const view = useHubView<Detail>({ kind: "fieldDetail", fieldId });
  const [busy, setBusy] = useState(false);
  const data = view.data;
  const ownRental = data?.reservation?.fieldId === fieldId;

  const action = async (hours: number, extend = false) => {
    setBusy(true);
    await adapter.dispatch({
      type: extend ? "field.extend" : "field.reserve",
      fieldId,
      hours,
      operationId: crypto.randomUUID(),
    });
    setBusy(false);
    await view.reload();
  };

  return <ViewFrame title={data?.field.name ?? "Field"} eyebrow="FIELD DETAILS" state={view.state} error={view.error}>
    {data && <>
      <Link className="back-link" to="/fields">&larr; All public Fields</Link>
      <div className="detail-grid">
        <article className="field-visual">
          <div className="field-map-grid">{Array.from(
            { length: Math.min(64, data.field.slots?.length ?? data.field.slotCount ?? 24) },
            (_, index) => <i key={index} />,
          )}</div>
          <h2>{data.field.region} &middot; Size {data.field.sizeClass}</h2>
          <p>{data.field.location}</p>
          <small>{data.field.allowedCrops?.length
            ? `Allowed crops: ${data.field.allowedCrops.join(", ")}`
            : "All crops allowed"}</small>
        </article>
        <article className="panel">
          <h2>{ownRental ? "Extend rental" : data.field.available ? "Rental plans" : "Currently rented"}</h2>
          {!data.field.available && !ownRental
            && <p className="notice">This Field is occupied. Its holder remains private.</p>}
          {data.rentPlans.map(plan => <button
            className="plan"
            disabled={busy || (!ownRental
              && (!data.field.available || data.progression.level < (data.field.requiredLevel ?? 1)))}
            key={plan.hours}
            onClick={() => void action(plan.hours, ownRental)}
          >
            <span><strong>{plan.hours} hours</strong><small>{plan.graceSurcharge
              ? "25% grace surcharge included"
              : "Real-time rental"}</small></span>
            <b>${plan.price.toLocaleString()}</b>
          </button>)}
          <p className="fine-print">Maximum accumulated expiry is 24 hours from now. Early release has no refund.</p>
        </article>
      </div>
    </>}
  </ViewFrame>;
}
