import { X } from "@phosphor-icons/react";
import type { PropsWithChildren } from "react";

interface Props extends PropsWithChildren {
  eyebrow: string;
  title: string;
  confirmLabel: string;
  pending?: boolean;
  tone?: "confirm" | "danger-confirm";
  onClose: () => void;
  onConfirm: () => void;
}

export function ConfirmDialog({ eyebrow, title, confirmLabel, pending, tone = "confirm", onClose, onConfirm, children }: Props) {
  return (
    <div className="dialog-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <section className="confirm-dialog" role="dialog" aria-modal="true" aria-labelledby="confirm-dialog-title">
        <button className="dialog-close" type="button" aria-label="Close" onClick={onClose}><X size={20} /></button>
        <span>{eyebrow}</span><h2 id="confirm-dialog-title">{title}</h2>
        <div className="dialog-content">{children}</div>
        <div className="dialog-actions"><button type="button" className="secondary-button" disabled={pending} onClick={onClose}>Cancel</button><button type="button" className={tone} disabled={pending} onClick={onConfirm}>{pending ? "Processing..." : confirmLabel}</button></div>
      </section>
    </div>
  );
}
