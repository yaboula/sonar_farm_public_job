# Origin baseline

`sonar_farm_publicjob` was bootstrapped from the reusable portions of the
`sonar_farm` working tree at commit `8064bab` on 12 August 2026.

The import intentionally includes the current local versions of the stabilized
farming, field topology, minigame, inspection and Hub building blocks. The
origin working tree contained local changes in:

- `client/modules/minigames/controller.lua`
- `client/modules/zones/slots.lua`
- `server/modules/minigames/sessions.lua`
- `web/public/assets/images/farm-office-background.webp`

Company-only backend modules, Company/Work frontend views, dependencies, build
outputs, caches and temporary QA artifacts were excluded. The source repository
is not a dependency and must never be modified by this resource.
