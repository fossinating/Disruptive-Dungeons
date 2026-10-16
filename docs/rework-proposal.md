# Disruptive Dungeons: Rework Proposal

**Pitch:** a 2D action roguelite where the dungeon hacks your robot. Disruption fields become the main mechanic instead of an obstacle.

## Background: jam results

2023 UNC Collegiate Game Jam (13 entries, 5 ratings):

| Criterion | Rank | Score |
| --------- | ---- | ----- |
| Fun       | #3   | 3.8   |
| Theme     | #5   | 3.4   |
| Visuals   | #6   | 2.8   |
| Overall   | #7   | 2.8   |
| Audio     | #10  | 1.2   |

Fun was the highest score across all of fossinating's jam entries. Players praised the snappy physics-based movement, the disruption-field gimmick and the procedural generation. Complaints were about polish, not design: no audio, small and hard-to-read UI, and dropping through platforms was never explained.

## What to keep

- Physics-based rolling movement that still feels snappy. This was the most-praised thing, so leave the feel alone.
- The four field colors: blue, green, red and purple. They're already the four color-coded flags in `Objects/DisruptionField.gd`.
- Equipment colored to match the field that disables it. A player figured that link out without any explanation, which shows it reads well.
- A field disables one color of upgrade and forces you to play another way. It should be something to work around, not a punishment.

## Story and run structure

You play SP-1N, captured by a scrapper gang. Each run is an escape attempt: you start on the scrapheap and fight through the scrapshop towards the exit. When you die, the gang strips your upgrades and throws you back on the scrapheap.

A run goes through 4 floors of generated rooms, and each floor has a boss scrapper. You salvage parts from the enemies you destroy, and between floors you install those parts at a workbench.

**Permanent progression** is unlocking new upgrade types, as in Dead Cells or Slay the Spire. You find a schematic in the world (boss drops, hidden rooms, elite enemies), and from then on that part can appear in every future run. You never start a run stronger. You start with more possible builds.

## Parts and colors

Every part has a color, and a field turns off every part of its color. A color is a theme, not a function: each color has its own weapons and its own utility parts. A red field never means "no weapons". It means "no red parts", and you fight with whatever else you built.

| Color  | Theme              | Example weapon                  | Example utility              |
| ------ | ------------------ | ------------------------------- | ---------------------------- |
| Blue   | Speed and momentum | Ram plating: damage from speed  | Boost                        |
| Green  | Air and vertical   | Ground-slam                     | Double jump                  |
| Red    | Heat and firepower | Shotgun                         | Heat vent that pushes you    |
| Purple | Gadgets and hacks  | Attack drone                    | Hack (see fields below)      |

The themes follow what each field disabled in the jam version, so the colors keep their meaning.

SP-1N's base chassis has no color: rolling, jumping and a weak basic shot always work. A field can take your build away, but never your ability to move and fight.

- **Slots:** you have a fixed number of slots and any part fits any slot. You find more parts than you have slots, so you choose what to keep.
- **Color synergy:** parts get stronger with other parts of their color (for example, "+10% damage per red part" or "blue parts build boost twice as fast"). This pulls you towards one color, and fields push you to spread out. A one-color build is the strongest until it meets its field, then it's back to the base chassis.
- **Multi-color parts:** they count as both colors. They synergize with both, and a field of either color turns them off.
- **Overload parts:** they only switch on _inside_ a field of their own color (for example, a green part that reads "inside a green field, your basic shot pierces"). They take a slot and do nothing outside that field, so they're a bet on meeting it.
- **Shielded colors:** a shield module makes one color ignore its field. It has to cost a lot, or it removes the mechanic:
  - it takes a slot
  - every other part of that color runs at reduced strength, all the time
  - you can only shield one color at once
  - it's rare, and it has to be unlocked with a schematic first

## Fields become dynamic

- **Room types:** a static field zone, a field that sweeps across the room, a field that pulses on a timer, a field that follows the player slowly, a field that changes color on a timer, and a field carried by an enemy (a "Jammer" bot).
- **Layouts:** two fields of different colors that overlap, a field that covers the whole room with a generator you can destroy, and safe pockets inside a large field.
- **Hacking:** a purple part, found during a run and unlocked with a schematic. With it you can flip which color a generator disables, on a cooldown. You don't have it at the start, and because it's a purple part, a purple field turns it off.
- Green and blue fields finally get used. The itch page already lists jump and acceleration fields as unfinished.

## Enemies

Build on `enemies/moving_enemy` and `enemies/flying_enemy`. Most of the roster is generic combat bots, which fill rooms and make the special ones stand out.

**Generic combat bots:**

- **Roller:** the existing ground enemy. Chases and rams.
- **Drone:** the existing flying enemy.
- **Gunner:** walks and shoots at range.
- **Charger:** winds up, then dashes in a straight line.
- **Bomber:** flies over you and drops explosives.
- **Sniper:** long-range shot with a visible aiming line.
- **Mortar:** lobs arcing shots over platforms.
- **Mites:** small, weak and in swarms.
- **Shield bot:** blocks shots from the front.
- **Turret:** fixed in place, must be hit from behind.
- **Tank:** slow, heavily armored, hits hard.

**Bots that interact with fields or parts:**

- **Jammer:** carries a disruption field with it.
- **Magnet bot:** pulls you into fields.
- **Splitter:** breaks into smaller bots when destroyed.
- **Scrapper:** steals one of your parts if it touches you. You get the part back by killing it.
- **Repair bot:** heals other bots and rebuilds destroyed generators.

Each floor also gets elite versions of the generic bots (more health, one extra behavior) so the later floors don't need a new roster.

## Combat

- **Weapon heat:** every weapon builds heat as it fires and locks out when it overheats. Parts can change how heat builds or what happens at high heat.
- **Shield durability:** the shield absorbs damage until it breaks, then regenerates after a delay.

A player suggested both during the jam.

## Fixes from jam feedback

- Make the UI 2–3× larger, and show the disabled colors next to the player instead of in the bottom-right corner.
- Add a first room that teaches dropping through platforms.
- Audio needs the most work, since it scored 1.2. Each color shutting down should have its own "powering down" sound, so you can tell what just failed without looking.

## Technical

- The project is already on Godot 4.0, so upgrading to 4.x is minor.
- Rewrite `map.gd` to favor big rooms, as the itch notes planned.
- Keep `Rooms/*.tscn` as hand-made room chunks that the generator stitches together, and add special room types (shop, workbench, schematic room).

## Scope

A medium-sized project. Ship a vertical slice first: 1 floor, 10 parts (2 per color and 2 multi-color), 6 enemies and 1 boss. The slice should answer one question: is it fun to lose one color of your build to a field and fight with the rest?
