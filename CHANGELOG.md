# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Dates are in format YYYY-MM-DD (year, month, day)

# [1.0.0-alpha.7] - 2026-01-14

## Changed

- Always launch the game in full-screen mode (no stuttering on Windows, no menu showing up on Mac, etc.)

## Fixed

- The speed boost is not stopped upon respawn. (#164)
- Speed boost end when out of track causes the velocity to reset to zero (huge braking) (#165)
- Collidable assets go back to their original position when approaching them (#158)

# [1.0.0-alpha.6] - 2025-11-23

## Changed

- Improved grass texture.
- Tweaked sky and exposure settings.

# [1.0.0-alpha.5] - 2025-10-04

## Added

- Added collision enabled decorations:
    - Added bins
    - Added benches
    - Added bus stop poles

## Changed

- Improved physics performance
- Switched to Sky3D procedural sky in-game and for the menus.
- Improved roads texture.
- Item slots now have different behaviour depending of the game mode:
    - In versus, random items are picked at a given interval.
    - Against the clock, the player has 3 speed boosts for the entire race.

## Fixed

- Cars can no longer drive on building walls

# [1.0.0-alpha.4] - 2025-09-23

## Added

- Added items given during the race (no distinction between game modes for now)
    - Added the speed boost item which gives a speed boost for a few seconds and allow going off track at maximum speed.
- Added a home screen.
- Added a credits screen.

## Changed

- Cars are less likely to bump into the ground.
- Cars should be slightly less bumpy between themselves and with walls.
- It is now much easier to go backwards especially in slopes.
- Stuck bots respawn after being idle for some time.
- Improved performance:
    - Improve framerate when the whole landscape is visible.
    - Reduce collision checks.

## Fixed

- Fixed UI blur backdrop filter shader.
- Tried to fix an occasional crash on respawn due to excessive velocity.

# [1.0.0-alpha.3] - 2025-08-31

## Added

- Added draft menus allowing to choose the mode, speed and track.
- Added 3 additional speed modes ("challenging" being the initial speed mode")

## Fixed

- Fixed error spam "query_info(): The axis Vector3 (0.0, 0.0, 0.0) must be normalized"

# [1.0.0-alpha.2] - 2025-08-24

## Added

- Added ranking:
    - Added a HUD for player live ranking, live position against others, position of the whole group on the track (gray bar), and car names.
    - Added a GUI for ranking at the end of the track. Ranks based on time, or by length completed if not finished.
    - Added 15 bots to play against.
- Added PBR materials:
    - Added PBR grass.
    - Added PBR road.
    - Added PBR render walls for building placeholders.
    - Added PBR hay replacing wheels for better physics performance.
- Added support for controllers.

## Changed

- Improved world environment.
- Switched to Forward+ Godot renderer.
- Centrifugal force is a bit less compensated while drifting, making it feel slightly more realistic.

## Fixed

- Fixed wheel adherence when going backwards.
- Fixed error spam on wall of wheels.

# [1.0.0-alpha.1] - 2025-08-13

- Initial release: driving alone on a track, with respawn functionality.