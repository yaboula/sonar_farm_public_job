import { type PropsWithChildren, useEffect, useState } from "react";
import { AppHeader } from "./AppHeader";
const WIDTH = 1440, HEIGHT = 810, INSET = 24;
export function calculateSurfaceScale(width: number, height: number) {
  return Math.min((width - INSET * 2) / WIDTH, (height - INSET * 2) / HEIGHT);
}
export function SurfaceStage({ children }: PropsWithChildren) {
  const [scale, setScale] = useState(() => calculateSurfaceScale(innerWidth, innerHeight));
  useEffect(() => { const resize = () => setScale(calculateSurfaceScale(innerWidth, innerHeight)); addEventListener("resize", resize); return () => removeEventListener("resize", resize); }, []);
  return <div className="world-stage"><section className="hub-canvas" style={{ "--hub-scale": String(Math.max(.35, scale)) } as React.CSSProperties}>
    <AppHeader /><main className="hub-content">{children}</main>
  </section></div>;
}
