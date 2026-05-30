## Noita Entangled Worlds v1.7.2

- Added an optional **Share all perks** setting. When enabled, perks picked up by one player are treated as shared/global perks and are applied to the other players.
- Added the wand showcase compare UI from the fork's master branch.
- Improved multiplayer sync safety by validating world updates, chunk data, chunk deltas, and chunk-map data before applying or forwarding them.
- Added oversized local-socket and peer-compressed-message guards to reject malformed payloads before they can allocate excessive memory.
- Suppressed unchanged or empty normal chunk-delta packets while preserving authority-transition updates.
- Fixed entity position/storage batching and `spawn_once` batching so final remainder entries are no longer skipped.
- Added guarded stale-authority detection for incoming chunk deltas, with snapshot recovery requests from the expected authority.
- Replaced unsafe pixel flag decoding with checked decoding and added structured logs for invalid payloads, malformed flags, stale chunk deltas, empty delta suppression, and map-worker shutdown.


## Accepted pull requests


No upstream pull requests have been accepted in this fork release.

## Installation


Download and unpack `noita_proxy-win.zip` or `noita_proxy-linux.zip`, depending on your OS. After that, launch the proxy.


Proxy is able to download and install the mod automatically. There is no need to download the mod (`quant.ew.zip`) manually.


You'll be prompted for a path to `noita.exe` when launching the proxy for the first time.
It should be detected automatically as long as you use steam version of the game and steam is launched.
        

## Updating


There is a button in bottom-left corner on noita_proxy's main screen that allows to auto-update to a new version when one is available
