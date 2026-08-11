import { createContext, type PropsWithChildren, useContext, useEffect, useState } from "react";
import { hubAdapter } from "../adapters/hubAdapter";
import type { HubContextModel } from "../types";

const HubContext = createContext<(HubContextModel & { adapter: typeof hubAdapter }) | null>(null);
export function HubProvider({ children }: PropsWithChildren) {
  const [model, setModel] = useState<HubContextModel | null>(null);
  useEffect(() => {
    let mounted = true;
    const hydrate = (value?: HubContextModel) => value
      ? setModel(value)
      : void hubAdapter.bootstrap().then((data) => mounted && setModel(data)).catch(() => undefined);
    const onMessage = (event: MessageEvent) => {
      if (event.data?.type === "hub:open") hydrate(event.data.payload);
      if (event.data?.type === "hub:close") setModel(null);
    };
    hydrate(); window.addEventListener("message", onMessage);
    const onKey = (event: KeyboardEvent) => { if (event.key === "Escape") void hubAdapter.close(); };
    window.addEventListener("keydown", onKey);
    return () => { mounted = false; window.removeEventListener("message", onMessage); window.removeEventListener("keydown", onKey); };
  }, []);
  if (!model) return <div className="hub-boot">Loading public farming Hub…</div>;
  return <HubContext.Provider value={{ ...model, adapter: hubAdapter }}>{children}</HubContext.Provider>;
}
export function useHub() { const value = useContext(HubContext); if (!value) throw new Error("HubProvider missing"); return value; }
