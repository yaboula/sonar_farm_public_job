import { useCallback, useEffect, useState } from "react";
import { useHub } from "../store/HubContext";
import type { HubViewRequest, ViewState } from "../types";
export function useHubView<T>(request: HubViewRequest) {
  const { adapter } = useHub(); const [state, setState] = useState<ViewState>("loading");
  const [data, setData] = useState<T>(); const [error, setError] = useState<string>();
  const requestKey = JSON.stringify(request);
  const reload = useCallback(async () => { setState("loading"); try { const view = await adapter.load<T>(JSON.parse(requestKey) as HubViewRequest); setState(view.state); setData(view.data); setError(view.reason); }
    catch (reason) { setState("error"); setError(reason instanceof Error ? reason.message : "Request failed"); } }, [adapter, requestKey]);
  useEffect(() => { void Promise.resolve().then(reload); }, [reload]); return { state, data, error, reload };
}
