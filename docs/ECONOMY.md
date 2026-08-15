# Economy configuration

All payments use the player's personal QB bank account.

## Rentals

- S: $300 / $800 / $1,500 / $1,900 for 1/3/6/8 hours.
- M: $480 / $1,300 / $2,400 / $3,000.
- L: $720 / $1,950 / $3,600 / $4,500.

Level discounts are 5% at L5, 12% at L10, 18% at L15 and 25% at L20. Grace extensions add 25% after the level discount. Expiry may never be accumulated beyond eight hours from the current server time. Existing 12/24-hour reservations are not shortened or refunded; while more than eight hours remain, every extension is rejected.

## Market

Basic stock is unlimited. Plus capacity is 20 and restores 5 every 30 minutes. Pro capacity is 10 and restores 2 every 60 minutes. Restock uses persistent real time.

The tablet costs $1,500 and is purchasable only at a physical Market. Other products can be purchased from either physical Market or a carried tablet.

Catalog quantity controls support both +/- buttons and direct keyboard entry. Values are clamped client-side to authoritative stock and the configured 99-unit per-line limit, then revalidated by the server during purchase.

## Sell

Standard unit prices are Carrot $12, Potato $10, Lettuce $14 and Tomato $16. Quality multipliers are Poor 0.5, Standard 1.0, Fine 1.5 and Premium 2.0. The personal level bonus is applied last, and each selected group subtotal is rounded once.

Only stacks with matching resource and producer metadata are eligible. Foreign, transferred or legacy produce is ignored.

## Recovery

Every debit/credit flow uses a caller operation ID. Reservation commits, Market deliveries and Sell credits are persisted before receipt finalization. A failed receipt transaction enters the `finalize_operation` outbox and remains replay-safe while reconciliation completes. Failed post-debit deliveries compensate the bank; failed credits enter the `bank_credit` outbox and are retried by the worker or `/sfpj_reconcile`.

QB-Core bank mutations and MySQL cannot share one atomic transaction. The resource therefore claims each credit outbox row before touching the bank. A row left in `processing` after a crash is intentionally not auto-replayed because its bank outcome is ambiguous; an administrator must compare the operation ID in QB transaction logs before resolving it. This favors protection from duplicate payouts over guessing.
