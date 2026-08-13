import { X } from "@phosphor-icons/react";
import { type PropsWithChildren, useEffect, useId, useRef } from "react";

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
  const titleId = useId();
  const descriptionId = useId();
  const dialogRef = useRef<HTMLElement>(null);
  const cancelRef = useRef<HTMLButtonElement>(null);
  const closeRef = useRef(onClose);
  const pendingRef = useRef(pending);
  useEffect(() => { closeRef.current = onClose; pendingRef.current = pending; });
  useEffect(() => {
    const previous = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    cancelRef.current?.focus();
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault(); event.stopImmediatePropagation();
        if (!pendingRef.current) closeRef.current();
        return;
      }
      if (event.key !== "Tab") return;
      const focusable = [...(dialogRef.current?.querySelectorAll<HTMLElement>("button:not(:disabled), [href], input:not(:disabled), select:not(:disabled), textarea:not(:disabled), [tabindex]:not([tabindex='-1'])") ?? [])];
      if (!focusable.length) return;
      const first = focusable[0]; const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
    };
    window.addEventListener("keydown", onKeyDown, true);
    return () => { window.removeEventListener("keydown", onKeyDown, true); previous?.focus(); };
  }, []);
  return (
    <div className="dialog-backdrop" role="presentation" onMouseDown={(event) => { if (!pending && event.target === event.currentTarget) onClose(); }}>
      <section ref={dialogRef} className="confirm-dialog" role="dialog" aria-modal="true" aria-labelledby={titleId} aria-describedby={descriptionId} aria-busy={pending}>
        <button className="dialog-close" type="button" aria-label="Close" disabled={pending} onClick={onClose}><X size={20} /></button>
        <span>{eyebrow}</span><h2 id={titleId}>{title}</h2>
        <div className="dialog-content" id={descriptionId}>{children}</div>
        <div className="dialog-actions"><button ref={cancelRef} type="button" className="secondary-button" disabled={pending} onClick={onClose}>Cancel</button><button type="button" className={tone} disabled={pending} onClick={onConfirm}>{pending ? "Processing..." : confirmLabel}</button></div>
      </section>
    </div>
  );
}
