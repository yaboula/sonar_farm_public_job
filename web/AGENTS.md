# Public Job Hub instructions

Run the local preview and verify changes directly when browser tooling is available. Keep the Sites handoff files intact and run `npm run build` plus `npm run test:sites` before delivery.

## Durable product decisions

- The product canvas is a fixed, opaque 1440 x 810 surface that scales uniformly.
- The only v1 routes are Today, Fields, Market and Sell.
- The only player role is an on-duty farmer; there are no companies, staff roles or business accounts.
- Tablet and physical Market/Sell surfaces reuse the same routes. The server-provided surface and capabilities decide which mutations are allowed.
- Remote Sell is browse-and-route only; confirmation is available solely at the Grapeseed buyer.
- Public Field views show availability and expiry, never the holder identity or co-op roster.
- Every view must support ready, loading, empty, error and restricted/unavailable presentation.
- Use Barlow Condensed for display headings, Source Sans 3 for body copy, warm yellow for actions and opaque charcoal surfaces.
- Keep developer fixtures and controls out of the FiveM production build.
- MySQL Field topology is authoritative at runtime. `Config.FieldSeeds` is the version-controlled import source.
- Item art uses the established matte 3D inventory language with a transparent background and no words or logos.
- The Inspection HUD remains a slim non-interactive agronomic rail and never takes NUI focus.
