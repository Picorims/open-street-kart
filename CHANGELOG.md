# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Dates are in format YYYY-MM-DD (year, month, day)

# [1.0.0-alpha.2] - ????-??-??

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