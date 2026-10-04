# Vertical-slice demo

A first playable pass at the slice in [`docs/rework-proposal.md`](../docs/rework-proposal.md). It tests one question: is it fun to lose one color of your build to a field and fight with the rest?

`project.godot` now starts this demo. To get back to the jam build, set the main scene to `res://UI/main_menu.tscn` again.

## Running it

Open the project in Godot 4.6 and press F5. The project was saved in 4.0, so the editor upgrades it and reimports assets the first time you open it.

Two headless checks, no window needed:

```sh
# Load every room on a random floor and fire every part.
godot --headless --path . res://demo/main.tscn -- --smoke
# Clear each room, then use the real controls to leave through every door,
# including vertical shafts and the locked boss door.
godot --headless --path . res://demo/main.tscn -- --traverse
```

## What's in it

- **A generated floor of about 11 rooms** (`demo/rooms.gd`). The rooms sit on a grid, with doors on any side, vertical shafts and a few loops. The tutorial start room teaches dropping through platforms. There's a workbench next to the start and another deeper in. Rooms get more bots and nastier fields the farther they are from the start.
- **Crawler structure:** doors seal until a room's bots are destroyed, and cleared rooms stay cleared when you backtrack. A minimap with fog of war shows visited rooms and outlines their neighbors. The Foreman's room hangs off the far end of the map behind a locked door, and a golden elite in another room carries the key.
- **12 parts:** 2 per color, 2 multi-color parts (Static Coil, Thruster Fins), an overload part (Field Siphon) and a shield module (Faraday Cage).
- **Fields:** static, sweeping, pulsing, color-cycling, following the player (it takes your most-used color), carried by a Jammer, overlapping, and a room-wide field with a generator you can destroy. Hack flips a field's color.
- **Bots:** Roller, Drone, Gunner, Charger, Jammer and Scrapper (it steals a part, and you get it back by killing it), plus the boss. The boss carries a color-cycling field, and below half health it calls for backup.
- **Systems:** color synergy (+15% per other active part of the same color), weapon heat with overheat lockout, a regenerating shield, salvage crates after each room, and stats on the death and win screens: time each color was offline, and damage by source.
- **Jam feedback:** the HUD is large, disabled colors show next to the player, and each color has its own procedural power-down sound.

Esc opens a debug menu: reveal the map, take the boss key, jump to the boss door, add every part to the stash, or turn on god mode.

## Where it departs from the proposal or the jam build

- **Camera:** it starts at 1.75× instead of 2.5×. At 2.5× you couldn't see the bots shooting at you.
- **Movement:** the constants are the jam's, with one change. Speed above the cap (from Boost, Heat Vent or recoil) is no longer clamped away the moment you press a direction, which Ram Plating needs.
- **Salvage and progression:** it's simplified. A room drops one random part when cleared, the workbenches hand out a few more, and there are no schematics or permanent unlocks yet.
- **Rooms:** they're generated from one fixed-size frame (a central platform spine plus random side layouts), not stitched together from `Rooms/*.tscn` like the proposal describes.
- **Art:** new bots reuse the jam sprites with a tint. Everything is built in code (`demo/*.gd`) instead of scenes, so it's fast to change while the plan moves.

Not built yet: the remaining enemies, elite variants beyond the key carrier, secret and treasure rooms, schematics, the shop, and more floors.
