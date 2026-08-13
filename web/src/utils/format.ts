export function formatRemaining(timestamp?: number, now = Math.floor(Date.now() / 1000)) {
  if (!timestamp) return "No active timer";
  const seconds = Math.max(0, timestamp - now);
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.ceil((seconds % 3600) / 60);
  return hours ? `${hours}h ${minutes}m` : `${minutes}m`;
}

export function formatDateTime(timestamp?: number) {
  if (!timestamp) return "Not scheduled";
  return new Intl.DateTimeFormat("en", {
    weekday: "short",
    day: "2-digit",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  }).format(timestamp * 1000);
}

export const money = (value: number) => `$${Math.max(0, value).toLocaleString("en-US")}`;
