import { CaretDown, Check } from "@phosphor-icons/react";
import { useEffect, useRef, useState } from "react";

interface Option { value: string; label: string }
interface Props { label: string; value: string; options: Option[]; onChange: (value: string) => void; className?: string }

export function FarmSelect({ label, value, options, onChange, className = "" }: Props) {
  const [open, setOpen] = useState(false);
  const root = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const close = (event: MouseEvent) => { if (!root.current?.contains(event.target as Node)) setOpen(false); };
    window.addEventListener("mousedown", close);
    return () => window.removeEventListener("mousedown", close);
  }, []);
  const selected = options.find((option) => option.value === value)?.label ?? value;
  return (
    <div ref={root} className={`farm-select ${open ? "is-open" : ""} ${className}`}>
      <button type="button" aria-label={label} aria-expanded={open} onClick={() => setOpen((current) => !current)}>
        <span>{selected}</span><CaretDown size={17} />
      </button>
      {open ? <div className="farm-select-menu" role="listbox" aria-label={label}>
        {options.map((option) => <button type="button" role="option" aria-selected={option.value === value} key={option.value} onClick={() => { onChange(option.value); setOpen(false); }}>{option.label}{option.value === value ? <Check size={15} /> : null}</button>)}
      </div> : null}
    </div>
  );
}
