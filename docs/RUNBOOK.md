# Administration runbook

## Health checks

1. Confirm `Runtime` reached ready and oxmysql did not report a schema failure.
2. Check pending economy work:

   ```sql
   SELECT status, kind, COUNT(*) FROM sfpj_economy_operations GROUP BY status, kind;
   SELECT * FROM sfpj_economy_outbox WHERE status IN ('pending', 'processing') ORDER BY created_at;
   ```

3. Check reservations and Field claims agree:

   ```sql
   SELECT r.id, r.field_id, r.status, r.expires_at, r.grace_until
   FROM sfpj_reservations r WHERE r.status IN ('active', 'grace');
   SELECT * FROM sfpj_field_claims;
   ```

## Safe interventions

Enable `Config.Debug` only in staging or a controlled maintenance window. Grant the ACE only to administrators.

- Inspect: `/sfpj_reservation <id|field>`.
- Release a stuck reservation: `/sfpj_release <id|field>`. This destroys its live crops and applies cooldowns.
- Set staging XP: `/sfpj_setxp <citizenid> <xp>`.
- Retry pending bank credits: `/sfpj_reconcile`.
- Activate a validated topology draft: `/sfpj_activate_field <field-id> <revision-id>`.

Do not edit `sfpj_field_claims` or `sfpj_player_links` independently. Their uniqueness is part of the concurrency model.

The in-game zone and slot builders save versioned drafts. Confirm terrain, headings, spacing, target reachability and overlap with multiple clients before activation. Activation is refused while the Field is reserved or contains crops.

## Restart behavior

Growth, rentals, grace and restock use persisted Unix time and continue while offline. On restart the resource reloads crops, advances expired reservations, purges completed grace periods and resumes economy reconciliation.

## Incident triage

- Purchase debited but delivery failed: find the operation ID. It should be `compensated` or `compensation_pending`.
- Sale inventory removed but bank credit failed: operation is `credit_pending`; do not manually give items back and credit money. Reconcile the outbox.
- Outbox row remains `processing` after a crash: compare its operation ID with QB bank transaction logs. If the credit exists, mark the operation/outbox complete; if it does not, return the outbox row to `pending`. Never retry it blindly.
- Operation remains `finalize_pending`: run `/sfpj_reconcile`; the external inventory/bank side effect already succeeded and only its durable receipt is pending.
- Field appears occupied with no active reservation: inspect `sfpj_field_claims` joined to `sfpj_reservations`, then use the release command if an active/grace row exists.
- Duplicate tablet: remove the excess administratively, then verify the ox_inventory `swapItems` hook is active.

Back up all `sfpj_*` tables before manual SQL intervention.
