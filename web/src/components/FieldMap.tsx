import { useMemo, useState } from "react";
import type { PublicFieldDetail } from "../types";

interface Props { field: PublicFieldDetail }

export function FieldMap({ field }: Props) {
  const [selectedRowId, setSelectedRowId] = useState<string>();
  const slots = useMemo(() => selectedRowId ? field.slots.filter((slot) => slot.rowId === selectedRowId) : [], [field.slots, selectedRowId]);
  const width = 720;
  const height = 330;
  return (
    <section className="field-map-shell" aria-label={`${field.name} topology`}>
      <header><div><span>Authoritative topology</span><strong>{field.rows.length} rows · {field.slots.length} slots</strong></div><small>Select a row to inspect its planting positions</small></header>
      <div className="field-map-stage">
        <svg viewBox={`0 0 ${width} ${height}`} role="group" aria-label={`${field.name} rows and slots`}>
          <defs><pattern id={`grid-${field.id}`} width="30" height="30" patternUnits="userSpaceOnUse"><path d="M 30 0 L 0 0 0 30" fill="none" stroke="currentColor" strokeWidth="1" /></pattern></defs>
          <rect className="field-map-grid" width={width} height={height} fill={`url(#grid-${field.id})`} />
          {field.rows.map((row, index) => {
            const y = 35 + index * Math.min(45, 260 / Math.max(1, field.rows.length - 1));
            const selected = selectedRowId === row.id;
            return <g key={row.id} className={`field-map-row${selected ? " is-selected" : ""}`} role="button" tabIndex={0} onClick={() => setSelectedRowId(selected ? undefined : row.id)} onKeyDown={(event) => { if (event.key === "Enter" || event.key === " ") setSelectedRowId(selected ? undefined : row.id); }}><text x="24" y={y + 5}>{row.label}</text><line x1="110" x2="680" y1={y} y2={y} /></g>;
          })}
          {slots.map((slot) => {
            const row = field.rows.find((item) => item.id === slot.rowId);
            const rowIndex = field.rows.findIndex((item) => item.id === slot.rowId);
            const slotIndex = Math.max(0, row?.slotIds.indexOf(slot.id) ?? slot.order - 1);
            const x = 125 + slotIndex * (530 / Math.max(1, (row?.slotIds.length ?? 2) - 1));
            const y = 35 + rowIndex * Math.min(45, 260 / Math.max(1, field.rows.length - 1));
            return <circle className="field-map-slot" key={slot.id} cx={x} cy={y} r="8"><title>{slot.id}</title></circle>;
          })}
        </svg>
        <div className="field-map-north"><span>N</span><i /></div>
      </div>
      <footer><span>Fixed 0° orientation</span><span>{selectedRowId ? field.rows.find((row) => row.id === selectedRowId)?.label : "All rows"}</span><span>{slots.length ? `${slots.length} visible slots` : "Select a row"}</span></footer>
    </section>
  );
}
