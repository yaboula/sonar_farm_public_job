# Releasing

Work only from `codex/publicjob-v1` until a reviewed merge. Use Conventional Commits and push each green module checkpoint.

Do not create `v0.1.0` merely because builds pass. The tag requires the complete [release checklist](RELEASE_CHECKLIST.md), including multi-client FiveM races and in-game placement approval.

Before tagging, update the changelog, verify the manifest version is `0.1.0`, build all three UIs, confirm the source `sonar_farm` working tree is unchanged, merge through review, then tag the reviewed commit.
