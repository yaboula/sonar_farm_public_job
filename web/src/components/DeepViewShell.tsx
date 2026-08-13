import { ArrowLeft } from "@phosphor-icons/react";
import type { PropsWithChildren, ReactNode } from "react";

interface Props extends PropsWithChildren {
  eyebrow: string;
  title: string;
  subtitle: string;
  backLabel: string;
  onBack: () => void;
  status?: ReactNode;
  actionBar?: ReactNode;
}

export function DeepViewShell({ eyebrow, title, subtitle, backLabel, onBack, status, actionBar, children }: Props) {
  return (
    <section className="deep-view">
      <div className="hub-backdrop" aria-hidden="true" />
      <button className="deep-back" type="button" onClick={onBack}><ArrowLeft size={17} />{backLabel}</button>
      <header className="deep-header"><div><span>{eyebrow}</span><h1>{title}</h1><p>{subtitle}</p></div>{status}</header>
      <div className="deep-content">{children}</div>
      {actionBar ? <footer className="deep-action-bar">{actionBar}</footer> : null}
    </section>
  );
}
