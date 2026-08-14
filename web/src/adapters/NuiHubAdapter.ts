import type { HubAdapter, HubContextModel, HubViewModel, HubViewRequest, IntentResult } from "../types";
declare global { interface Window { GetParentResourceName?: () => string; invokeNative?: unknown } }
type Response<T> = { ok: boolean; data?: T; reason?: string; message?: string };
export function isNuiRuntime() {
  try {
    return typeof window.GetParentResourceName === "function" ||
      typeof window.parent?.GetParentResourceName === "function" ||
      window.invokeNative !== undefined ||
      window.parent?.invokeNative !== undefined;
  } catch {
    return false;
  }
}
export class NuiHubAdapter implements HubAdapter {
  private resource = (typeof window.GetParentResourceName === "function" ? window.GetParentResourceName() : window.parent?.GetParentResourceName?.()) ?? "sonar_farm_publicjob";
  private async request<T>(name: string, payload: unknown): Promise<T> {
    const response = await fetch(`https://${this.resource}/${name}`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(payload) });
    const result = await response.json() as Response<T>;
    if (!response.ok || !result.ok) throw new Error(result.message ?? result.reason ?? `${name} failed`);
    return result.data as T;
  }
  bootstrap() { return this.request<HubContextModel>("hub:bootstrap", {}); }
  load<T>(request: HubViewRequest) { return this.request<HubViewModel<T>>("hub:load", { request }); }
  async dispatch(intent: Record<string, unknown>): Promise<IntentResult> {
    const response = await fetch(`https://${this.resource}/hub:dispatch`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ intent }) });
    return response.json() as Promise<IntentResult>;
  }
  async close() { await this.request("hub:close", {}); }
}
