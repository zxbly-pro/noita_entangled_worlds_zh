# Sync Performance And Stability Rollout

This plan tracks conservative improvements for world sync, entity sync, and network stability. The goal is not to make perfect sync promises, but to reduce wasted work, reject malformed state safely, improve recovery from stale authority, and leave enough logs for future diagnosis.

## Goals

- Reduce repeated empty world-sync traffic and CPU spent encoding unchanged chunks.
- Prevent malformed local or peer messages from allocating excessive memory or applying invalid world data.
- Keep entity authority/storage updates complete across all entity counts.
- Detect stale chunk authority updates and recover with a full chunk refresh instead of silently applying bad state.
- Preserve gameplay stability by shipping risky terrain/explosion behavior behind opt-in settings.
- Emit logs that include message type, chunk/entity id, source peer, authority peer, priority, and recovery action.

## Rollout Order

1. Add instrumentation and validation.
   - Cap length-prefixed local socket messages.
   - Validate world update run lengths before applying or forwarding.
   - Add structured warning logs for rejected socket frames, invalid world updates, stale authority messages, and recovery requests.
   - Keep warnings concise but self-contained for future agent context.

2. Implement low-risk performance fixes.
   - Suppress empty chunk delta packets unless a protocol state transition needs the packet.
   - Add cheap `ChunkDelta::is_empty()` and `Chunk::any_changed()` helpers.
   - Avoid scanning/compressing unchanged chunks where possible.
   - Fix entity/spawn batching so the final remainder is processed instead of being skipped.

3. Add guarded authority recovery.
   - Track expected chunk authorities in listener states.
   - Reject deltas from non-authority peers.
   - On rejection, unload/re-request the chunk or request a full listen snapshot from the current authority.
   - Log the stale source, expected authority, chunk, priority, and chosen recovery action.

4. Gate higher-risk terrain/explosion behavior.
   - Keep solid-cell decode/explosion behavior unchanged by default.
   - Add explicit settings before changing terrain mutation semantics.
   - Prefer opt-in testing with extra diagnostics before enabling by default.

5. Soak-test focused scenarios.
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
