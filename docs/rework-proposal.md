# Disruptive Dungeons: Rework Proposal

**Pitch:** a 2D action roguelite where the dungeon hacks your robot. Disruption fields become the main mechanic instead of an obstacle.

## Background: jam results

2023 UNC Collegiate Game Jam (13 entries, 5 ratings):

| Criterion | Rank | Score |
|---|---|---|
| Fun | #3 | 3.8 |
| Theme | #5 | 3.4 |
| Visuals | #6 | 2.8 |
| Overall | #7 | 2.8 |
| Audio | #10 | 1.2 |

Fun was the highest score across all of fossinating's jam entries. Players praised the snappy physics-based movement, the disruption-field gimmick and the procedural generation. Complaints were about polish, not design: no audio, small and hard-to-read UI, and dropping through platforms was never explained.

## What to keep

- Physics-based rolling movement that still feels snappy. This was the most-praised thing, so leave the feel alone.
- The four subsystems as the core idea: movement, jump, weapons and skills. They're already the four color-coded flags in `Objects/DisruptionField.gd`.
- The colored equipment slots that match the field disabling them. A player figured that link out without any explanation, which shows it reads well.

## Core loop

Each run goes through 4 floors of generated rooms, and each floor has a boss scrapper. You salvage parts from the enemies you destroy, and between floors you install those parts at a workbench.

## The main new idea: routing

Right now a field simply turns a system off. In the rework, every part is wired to one of the four subsystems, and a field hits every part on the circuit it disables.

- Put a shotgun and a dash on the same circuit and one field takes out both.
- Spread your parts across circuits and you're harder to shut down, but each circuit has limited power, so every part you add makes the others weaker.
- **Shielded circuits:** rare upgrades that ignore one color of field.
- **Overload parts:** they only switch on *inside* a field (for example, "while jump is disrupted, gain a ground-slam").

This gives the build-making you'd expect from a roguelite, and every choice comes back to the jam's disruption theme. No other game has this mechanic.

## Fields become dynamic

- **Room types:** a static field zone, a field that sweeps across the room, a field that pulses on a timer, and a field carried by an enemy (a "Jammer" bot).
- **Hacking:** you can shoot a field generator to flip which system it disables, at a cost. That means fields sometimes help you.
- Fields for jump and acceleration finally get used. The itch page already lists this as unfinished.

## Enemies (about 8, up from 2)

Build on `enemies/moving_enemy` and `enemies/flying_enemy`, then add:

- **Jammer:** carries a disruption field with it.
- **Shielded tank.**
- **Turret** that must be hit from behind.
- **Splitter:** breaks into smaller bots when destroyed.
- **Magnet bot:** pulls you into fields.
- **Scrapper:** steals one of your parts if it touches you. You get the part back by killing it.

## Story in the game

You play SP-1N, and the gang boss is taking you apart. Each floor's boss has one of *your own* missing modules, and beating them restores it for every future run. This works as the permanent progression between runs, and it builds the story into the game itself, which was also on the itch page's to-do list.

## Fixes from jam feedback

- Make the UI 2–3× larger, and show the disabled systems next to the player instead of in the bottom-right corner.
- Add a first room that teaches dropping through platforms.
- Give the gun heat and give the shield durability that regenerates. A player suggested both.
- Audio needs the most work, since it scored 1.2. Each subsystem shutting down should have its own "powering down" sound, so you can tell what just failed without looking.

## Technical

- The project is already on Godot 4.0, so upgrading to 4.x is minor.
- Rewrite `map.gd` to favor big rooms, as the itch notes planned.
- Keep `Rooms/*.tscn` as hand-made room chunks that the generator stitches together, and add special room types (shop, workbench, hack room).

## Scope

A medium-sized project. Ship a vertical slice first: 1 floor, 8 parts, 4 enemies and 1 boss. The slice should answer one question: is routing parts across circuits fun?
