import { CaretDown, Check } from "@phosphor-icons/react";
import { useEffect, useId, useRef, useState } from "react";

interface Option { value: string; label: string }
interface Props { label: string; value: string; options: Option[]; onChange: (value: string) => void; className?: string }

export function FarmSelect({ label, value, options, onChange, className = "" }: Props) {
  const [open, setOpen] = useState(false);
  const [focusIndex, setFocusIndex] = useState(0);
  const root = useRef<HTMLDivElement>(null);
  const trigger = useRef<HTMLButtonElement>(null);
  const optionRefs = useRef<Array<HTMLButtonElement | null>>([]);
  const listboxId = useId();
  useEffect(() => {
    const close = (event: MouseEvent) => { if (!root.current?.contains(event.target as Node)) setOpen(false); };
    window.addEventListener("mousedown", close);
    return () => window.removeEventListener("mousedown", close);
  }, []);
  useEffect(() => { if (open) optionRefs.current[focusIndex]?.focus(); }, [focusIndex, open]);
  const selected = options.find((option) => option.value === value)?.label ?? value;
  const openMenu = (index = Math.max(0, options.findIndex((option) => option.value === value))) => {
    setFocusIndex(index); setOpen(true);
  };
  const closeMenu = (restoreFocus = false) => { setOpen(false); if (restoreFocus) requestAnimationFrame(() => trigger.current?.focus()); };
  return (
    <div ref={root} className={`farm-select ${open ? "is-open" : ""} ${className}`}>
      <button ref={trigger} type="button" aria-label={label} aria-haspopup="listbox" aria-controls={listboxId} aria-expanded={open}
        onClick={() => open ? closeMenu() : openMenu()}
        onKeyDown={(event) => { if (event.key === "ArrowDown" || event.key === "ArrowUp") { event.preventDefault(); openMenu(event.key === "ArrowUp" ? options.length - 1 : Math.max(0, options.findIndex((option) => option.value === value))); } }}>
        <span>{selected}</span><CaretDown size={17} />
      </button>
      {open ? <div id={listboxId} className="farm-select-menu" role="listbox" aria-label={label}>
        {options.map((option, index) => <button ref={(node) => { optionRefs.current[index] = node; }} type="button" role="option" aria-selected={option.value === value} key={option.value}
          onClick={() => { onChange(option.value); closeMenu(true); }}
          onKeyDown={(event) => {
            if (event.key === "ArrowDown" || event.key === "ArrowUp") { event.preventDefault(); setFocusIndex((current) => (current + (event.key === "ArrowDown" ? 1 : -1) + options.length) % options.length); }
            else if (event.key === "Home" || event.key === "End") { event.preventDefault(); setFocusIndex(event.key === "Home" ? 0 : options.length - 1); }
            else if (event.key === "Escape" || event.key === "Tab") { if (event.key === "Escape") event.preventDefault(); closeMenu(event.key === "Escape"); }
          }}>{option.label}{option.value === value ? <Check size={15} /> : null}</button>)}
      </div> : null}
    </div>
  );
}
