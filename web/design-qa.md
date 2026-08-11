# Public Job Hub visual QA

The rebuilt v1 Hub was rendered at 1280 x 720, 1920 x 1080 and 2560 x 1080 using the browser fixture adapter.

- The logical 1440 x 810 canvas stays opaque, centered and uniformly scaled.
- Today, Fields, Market and Sell share the approved typography, charcoal hierarchy and warm-yellow actions.
- No page-level overflow, cropped persistent action or world transparency was observed.
- Field cards expose region, size, availability and time only.
- Market shows personal pricing, tier locks and global stock; Sell shows an exact grouped preview.
- Sell totals use the same subtotal rounding rule as the server.
- Browser console validation completed with zero errors and zero warnings.

Real in-game validation of world targets, terrain snap, L64 culling and physical NPC placement remains part of the release checklist.
