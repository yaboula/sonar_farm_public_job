const messages: Record<string, string> = {
  job_required: "You must be employed as a farmer.",
  duty_required: "Go on duty before using the public farming Hub.",
  tablet_required: "A Farmer Tablet is required for remote access.",
  presence_required: "Visit the physical terminal to confirm this action.",
  reservation_required: "You do not participate in this Field.",
  reservation_inactive: "This reservation is no longer active.",
  reservation_grace: "Planting is blocked during the grace period.",
  already_participating: "You already participate in another Field.",
  owner_required: "Only the reservation owner can perform this action.",
  level_required: "Your farming level does not unlock this option.",
  field_unavailable: "That Field was reserved by another farmer.",
  field_cooldown: "Your same-Field cooldown is still active.",
  maximum_expiry: "A reservation cannot extend beyond 24 hours from now.",
  stock_unavailable: "Global stock changed before checkout. Your cart was kept.",
  insufficient_funds: "Your personal bank balance is insufficient.",
  inventory_full: "Your inventory cannot receive the complete order.",
  inventory_changed: "Your inventory changed before confirmation. Try again.",
  sale_pending: "Produce was accepted; bank credit is queued for reconciliation.",
  field_not_found: "Field not found in active catalog.",
  invalid_plan: "Invalid rental plan selected.",
  invalid_session: "Session expired. Reopen the tablet.",
};

export function rejectionMessage(reason: string | undefined, fallback: string) {
  return reason ? (messages[reason] ?? `Reservation rejected (${reason}).`) : fallback;
}
