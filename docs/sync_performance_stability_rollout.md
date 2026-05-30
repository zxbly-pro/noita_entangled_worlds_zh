# Sync Performance And Stability Rollout

This plan tracks conservative improvements for world sync, entity sync, and network stability. The goal is not to make perfect sync promises, but to reduce wasted work, reject malformed state safely, improve recovery from stale authority, and leave enough logs for future diagnosis.

## Goals

- Reduce repeated empty world-sync traffic and CPU spent encoding unchanged chunks.
- Prevent malformed local or peer messages from allocating excessive memory or applying invalid world data.
- Keep entity authority/storage updates complete across all entity counts.
- Detect stale chunk authority updates and recover with a full chunk refresh instead of silently applying bad state.
- Preserve gameplay stability by shipping risky terrain/explosion behavior behind opt-in settings.
- Emit logs that include message type, chunk/entity id, source peer, authority peer, priority, and recovery action.

## Current Status

Completed in `codex/sync-stability-rollout` commit `9c56b0cc` and included in the `v1.7.2` release branch:

- Added a saved rollout plan and log-context checklist.
- Added a 64 MiB cap for length-prefixed local socket frames.
- Added a 64 MiB declared-output cap for peer-compressed messages before decompression.
- Added validation for world updates, chunk data, chunk deltas, and chunk-map data before applying or forwarding them.
- Replaced unsafe pixel flag transmute decoding with checked nibble decoding.
- Added structured warning/debug logs for invalid payloads, malformed flags, compressed-message failures, stale chunk deltas, empty delta suppression, and world-map worker shutdown.
- Suppressed unchanged and empty normal chunk-delta packets while preserving authority-transition behavior.
- Fixed entity position/storage batching and `spawn_once` batching so remainder entries are not skipped.
- Added guarded stale-authority detection for incoming chunk deltas with snapshot recovery from the expected authority.
- Made the chunk-map image worker stop when its channels close.

Verified:

- `cargo fmt`
- `git diff --check`
- `cargo check -q -p shared -p noita_proxy`
- `cargo test -q -p shared`
- `cargo test -q -p noita_proxy --lib world_model::chunk::test_changed`

Known verification gap:

- `cargo check -q -p ewext` could not be run on this Mac host because `noita_api/src/noita/init_data.rs` uses target-specific inline asm with `eax`. The `ewext` edits were reviewed manually but still need a Windows/cross-target build check.

Remaining work:

- Run a real two-player gameplay soak with logs enabled.
- Cross-build or Windows-build `ewext`.
- Add sequence numbers and periodic reliable snapshots before moving high-frequency world/player state to unreliable/latest-state transport.
- Add explicit opt-in settings before changing solid terrain decode or explosion/black-hole terrain mutation semantics.
- Consider periodic debounced host checkpoints for world chunks, DES entity storage, and flags.
- Turn repeated warning patterns from soak logs into targeted tests or recovery improvements.

## Rollout Order

1. Completed: Add instrumentation and validation.
   - Cap length-prefixed local socket messages.
   - Validate world update run lengths before applying or forwarding.
   - Add structured warning logs for rejected socket frames, invalid world updates, stale authority messages, and recovery requests.
   - Keep warnings concise but self-contained for future agent context.

2. Completed: Implement low-risk performance fixes.
   - Suppress empty chunk delta packets unless a protocol state transition needs the packet.
   - Add cheap `ChunkDelta::is_empty()` and `Chunk::any_changed()` helpers.
   - Avoid scanning/compressing unchanged chunks where possible.
   - Fix entity/spawn batching so the final remainder is processed instead of being skipped.

3. Completed: Add guarded authority recovery.
   - Track expected chunk authorities in listener states.
   - Reject deltas from non-authority peers.
   - On rejection, unload/re-request the chunk or request a full listen snapshot from the current authority.
   - Log the stale source, expected authority, chunk, priority, and chosen recovery action.

4. Remaining: Gate higher-risk terrain/explosion behavior.
   - Keep solid-cell decode/explosion behavior unchanged by default.
   - Add explicit settings before changing terrain mutation semantics.
   - Prefer opt-in testing with extra diagnostics before enabling by default.

5. Remaining: Soak-test focused scenarios.
   - Two-player join, host/client reconnect, and host world transition.
   - Fast movement across chunks while another player listens nearby.
   - Authority handoff when two players approach the same chunk.
   - Item/entity handoff at interest boundaries.
   - Black holes, explosions, beamstone cuts, and cell eater effects.

## Log Context Checklist

Future logs should include these fields when relevant:

- `event`: stable event name such as `invalid_world_update`, `empty_delta_suppressed`, `stale_chunk_delta`, `authority_recovery`.
- `chunk`: chunk coordinate.
- `source`: source peer id.
- `expected`: expected authority peer id.
- `priority`: chunk priority.
- `runs` and `pixels`: world-update payload shape.
- `action`: drop, request_snapshot, unload, retry, or save.
- `world_num`: current world number when available.

## Safety Notes

- Do not make authoritative world decode stricter without a resync path.
- Do not move high-frequency sync to unreliable transport without sequence numbers and periodic reliable snapshots.
- Do not enable solid terrain creation/removal changes by default until dedicated gameplay testing confirms stability.
- Prefer warning logs for recoverable sync anomalies and error logs for local socket/protocol failures that disconnect Noita.
