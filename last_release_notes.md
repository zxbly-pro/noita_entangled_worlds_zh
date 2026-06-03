## Noita Entangled Worlds v1.8.4

- Expanded the wand showcase UI so it can display the full inventory instead of only the active wand.
- Fixed stale remote entity-sync cleanup on world init and peer reset, reducing the chance of runaway update loops after starting a new game.
- Guarded invalid physics-body handles so entity sync does not repeatedly call Noita physics APIs with the invalid `2147483647` sentinel.
- Fixed remote wand sync so it no longer tries to reposition a wand after choosing to kill and replace it.
- Cleared additional per-world EW state on world init to avoid carrying stale player, camera, spawn, and FPS bookkeeping into a fresh run.


## Accepted pull requests


No upstream pull requests have been accepted in this fork release.

## Installation


Download and unpack `noita_proxy-win.zip` or `noita_proxy-linux.zip`, depending on your OS. After that, launch the proxy.


Proxy is able to download and install the mod automatically. There is no need to download the mod (`quant.ew.zip`) manually.


You'll be prompted for a path to `noita.exe` when launching the proxy for the first time.
It should be detected automatically as long as you use steam version of the game and steam is launched.
        

## Updating


There is a button in bottom-left corner on noita_proxy's main screen that allows to auto-update to a new version when one is available
