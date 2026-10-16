# Rework demo

A playable build of [`docs/rework-proposal.md`](../docs/rework-proposal.md). It started as the vertical slice and now covers the full run structure. It tests one question: is it fun to lose one color of your build to a field and fight with the rest?

`project.godot` now starts this demo. To get back to the jam build, set the main scene to `res://UI/main_menu.tscn` again.

## Running it

Open the project in Godot 4.6 and press F5. The project was saved in 4.0, so the editor upgrades it and reimports assets the first time you open it.

Three headless checks, no window needed:

```sh
# Load every room on all four floors, installing and firing every part along the way.
godot --headless --fixed-fps 60 --path . res://demo/main.tscn -- --smoke
# Clear each room, then use the real controls to leave through every door on every floor,
# including vertical shafts, the locked boss doors and the cracked walls to hidden rooms.
godot --headless --fixed-fps 60 --path . res://demo/main.tscn -- --traverse
# Spawn every bot (plain and elite) and every boss and let them act, then check the newer
# parts, a Repair Bot rebuilding a generator, the shop, the hidden stash and safe pockets.
godot --headless --fixed-fps 60 --path . res://demo/main.tscn -- --bestiary
```

`--fixed-fps 60` runs them as fast as the machine allows instead of in real time. The checks use their own unlocks file, so they never touch your schematics.

## What's in it

- **Four floors** (`demo/rooms.gd`, `FLOORS`): The Scrapheap, The Sorting Line, The Chop Shop and The Loading Bay. Each one is a bigger generated map with its own roster and more elites. The rooms sit on a grid, with doors on any side, vertical shafts and a few loops. The first room teaches dropping through platforms. Rooms get more bots and nastier fields the farther they are from the start, and later floors start with the nastier field layouts.
- **Crawler structure:** doors seal until a room's bots are destroyed, and cleared rooms stay cleared when you backtrack. A minimap with fog of war shows visited rooms and outlines their neighbors. Each floor's boss is behind a locked door, and an elite somewhere carries the key. A freight lift in the boss room takes you up a floor, keeping your parts and patching some hull.
- **Four bosses:**
  - **The Foreman** carries a color-cycling field and calls for backup.
  - **The Magnate** carries a field in the color you rely on most, drags you toward it and scatters short-lived fields.
  - **The Chopper** has two fields of different colors orbiting it, throws saws that bounce off walls, and lobs shells.
  - **Boss Rust** has a field that stalks you in your main color and summons elite bodyguards. In its second phase it floods the room with two fields held up by generators you can shoot.
- **17 parts:** 2 or more per color, 3 multi-color parts (Static Coil, Thruster Fins, Afterburner), 2 overload parts (Field Siphon, Overclock) and a shield module (Faraday Cage). New since the slice:
  - **Spring Heels:** stomp bots from above.
  - **Flak Cannon:** exploding shells.
  - **Afterburner:** leaves a fire trail at high speed.
  - **Decoy:** bots aim at a hologram instead of you.
  - **Overclock:** inside a red field, you build no heat and parts recharge twice as fast.
- **Schematics** (`demo/unlocks.gd`): eight parts are locked at first, including Hack and the Faraday Cage, as the proposal asks. Bosses always drop a schematic while any are left, elites sometimes do, and every hidden stash has one. A schematic unlocks its part for every run after (saved to `user://unlocks.json`) and puts a copy in your stash. You never start a run stronger, only with more possible builds.
- **Fields:**
  - static, sweeping, pulsing and color-cycling fields
  - a field that follows you (it takes your most-used color)
  - a field carried by a Jammer
  - overlapping fields
  - a room-wide field with a generator you can destroy
  - a room-wide field with safe pockets cut out of it

  Hack flips a field's color.
- **Bots:** generic combat bots, plus bots that interact with fields or parts. Every generic bot also has an elite version with one extra behavior (for example, an elite Charger dashes twice, an elite Turret swings around, and an elite Splitter splits into three).

  | Generic combat bots | Bots that interact with fields or parts |
  | --- | --- |
  | Roller, Drone, Gunner, Charger, Sniper, Mortar, Mites, Shield Bot, Turret, Tank, Bomber | Jammer, Magnet Bot, Splitter, Scrapper, Repair Bot |

  Some bots counter particular colors:
  - Shield Bots and Turrets block hits from the front, so you have to get behind them, stomp them or blow them up.
  - Tanks shrug off small arms but take full damage from rams, slams, vents, lightning and fire.
  - Repair Bots heal other bots and rebuild generators you destroyed.
- **Special rooms:**
  - **The Fence**, a shop where you spend the scrap bots drop
  - **a vault** with a guarded chest holding a rarer part
  - **a hidden stash** behind a cracked wall, off the map until you shoot your way in
  - **two workbenches** per floor
- **Systems:**
  - color synergy (+15% per other active part of the same color)
  - weapon heat with overheat lockout
  - a regenerating shield
  - salvage crates after each room
  - stats on the death and win screens: time each color was offline, damage by source and schematics found
- **Jam feedback:** the HUD is large, disabled colors show next to the player, and each color has its own procedural power-down sound.

Esc opens a debug menu with these options:
- reveal the map
- take the boss key
- jump to the boss door
- skip to the next floor
- add every part to the stash
- forget your schematics
- turn on god mode

## Where it departs from the proposal or the jam build

- **Camera:** it starts at 1.75× instead of 2.5×. At 2.5× you couldn't see the bots shooting at you.
- **Movement:** the constants are the jam's, with one change. Speed above the cap (from Boost, Heat Vent or recoil) is no longer clamped away the moment you press a direction, which Ram Plating needs.
- **Salvage:** a room drops one random part when cleared, the workbenches hand out a few more, and the shop and vaults sell or hold the rest.
- **Rooms:** they're generated from one fixed-size frame (a central platform spine plus random side layouts), not stitched together from `Rooms/*.tscn` like the proposal describes.
- **Art:** new bots and bosses reuse the jam sprites with a tint and a few drawn details (shields, barrels, aiming lines). Everything is built in code (`demo/*.gd`) instead of scenes, so it's fast to change while the plan moves.

## Not built yet

- Hand-made room chunks from `Rooms/*.tscn`.
- Real art and music for the new bots, bosses and rooms.
- Balance. The numbers for the floors, bosses, prices and drop rates are first guesses that haven't been playtested.
