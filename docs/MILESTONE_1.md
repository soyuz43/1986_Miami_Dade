# Milestone 1 Implementation Notes — Crash Opening

**Status:** Complete and verified.

**Research basis:** `docs/RESEARCH_crash.md` (read that first).

---

## What runs

Pressing Play opens `scenes/main.tscn` directly into the crash. There is no menu and no setup
screen. The sequence is a scripted, keyframed animation, not a physics simulation.

| Control | Action |
|---------|--------|
| `R` | Restart the opening from the beginning |
| `C` | Toggle between the tracking camera and the fixed inspection overview |

The HUD always states that the scene is a blockout reconstruction whose layout was estimated
from written sources rather than the FBI's official Exhibit A diagram, and it flags that the
phase timing is relative because the FBI incident report and the Miami Herald reconstruction
disagree about when the car stop occurred.

## Files

| File | Role |
|------|------|
| `scenes/main.tscn` | Main scene: camera, lighting, environment, HUD |
| `scripts/crash/crash_scene.gd` | Scene controller: blockout setup, camera, HUD, key handling |
| `scripts/crash/crash_sequence.gd` | The deterministic keyframed crash sequence and phase state |
| `scripts/crash/crash_blockout.gd` | Static environment: road, sidewalks, yard, tree, wall, layout constants |
| `scripts/crash/vehicle_factory.gd` | Primitive box-shaped vehicle builder |
| `scripts/crash/crash_verifier.gd` | Headless verification harness |
| `scripts/crash/capture_shots.gd` | Screenshot tool for reviewing staging |

## Coordinate system

Godot defaults: `-X` west, `+X` east, `-Z` north, `+Z` south, `+Y` up.

Southwest 82nd Avenue runs north/south along the **Z** axis. The subject vehicle travels
**southbound** during the pursuit, then U-turns and ends **facing northbound**, which the FBI
incident report states explicitly. The crash scene and the final resting places are on the
**west** side of the avenue, matching "a front yard at 12201 Southwest 82nd Avenue" and the
retaining wall "on the west side of 82nd Avenue".

All layout constants live in `scripts/crash/crash_blockout.gd` so the spatial assumptions are
in one auditable place rather than scattered through the animation.

## Sequence phases

Driven by `CrashSequence`, keyed against a relative timeline (no wall-clock time is claimed):

| Phase | Approx. sequence time | What it shows |
|-------|----------------------|---------------|
| Approach | 0.0 - 2.6 s | Four vehicles southbound in separate lanes |
| Car stop ordered | 2.6 - 4.0 s | Grogan orders the felony car stop; the subject car swerves right off the pavement |
| First ram | 4.0 - 6.0 s | Manauzzi closes on the driver side and rams; Hanlon pulls up on the passenger side |
| U-turn | 6.0 - 7.6 s | The subject car swings around to face northbound |
| Second ram | 7.6 - 8.8 s | Manauzzi rams the driver side again |
| Impact | 8.8 - 10.6 s | The pair go over the sidewalk into the yard, striking the tree and the parked car |
| Settled | 10.6 s onward | Vehicles at their documented resting places; inspection camera takes over |

## Verification

Run the headless harness:

```
godot --headless --path . --script res://scripts/crash/crash_verifier.gd
```

It asserts:

1. **Determinism** - two independent runs produce identical vehicle transforms.
2. **End state** - the subject vehicle faces northbound, is west of the road, is wedged
   against the tree and the parked civilian car, and is in contact with Manauzzi's car;
   the Hanlon/Mireles car rests on the west side south of the subject vehicle; the Grogan/Dove
   car rests behind (south of) it.
3. **Restart** - `start()` returns every vehicle to its opening position, resets the clock and
   clears the finished flag, and a second full run reproduces the same end state.
4. **No pass-through** - using a separating-axis overlap test on oriented rectangles, no
   vehicle pair interpenetrates by more than one vehicle length. Deep overlap would mean one
   car drove clean through another.

The harness was validated by mutation testing: deliberately breaking `start()` makes the
restart check fail, and deliberately dropping a keyframe makes the path validator report a
mismatched path. Both were confirmed to produce failures, so the checks are not vacuous.

Review staging visually with:

```
godot --path . scenes/capture_shots.tscn --resolution 1280x720
```

Output is written to the user data directory under `crash_shots`.

---

## What this is and is not

**Is:** a deterministic, repeatable, source-informed blockout of the pursuit and crash that
opens the simulation.

**Is not:** a validated reconstruction. Specifically:

- **Absolute scale is not authoritative.** The FBI's Exhibit A diagram (final vehicle
  positions) and the aerial photographs were not transcribed, so all distances are estimates
  derived from written descriptions. The relative arrangement is the sourced part; the
  metres are not.
- **No wall-clock time is shown.** The FBI incident report puts the car stop near 9:32 a.m.
  and the Miami Herald reconstruction puts it near 9:19 a.m. That discrepancy is unresolved
  and is surfaced in the HUD rather than hidden.
- **The camera is a visualization choice.** There was no camera at the actual event. The
  tracking camera during playback and the inspection overview are presentational.
- **Not modelled:** radiator fluid, the three-foot posts, melaleuca trees, vehicle paint
  transfer, glass breakage, injuries, the gunfight, and the disputed round count. These
  belong to later milestones.
- **Not modelled:** which FBI vehicle initiated the first contact. The FBI incident report
  places Manauzzi's ram before Hanlon's; the Miami Herald describes Hanlon pulling alongside
  and being struck. The animation follows the FBI account and the HUD does not claim the
  order is settled.

## Known follow-ups for later milestones

- The old prototype `scripts/core/simulation_driver.gd` and its scene wiring are no longer
  used by `main.tscn`; the `data/` resources and `SimulationManager` autoload remain in place
  for Milestone 2.
- `SimulationManager` still has the event-dispatch and seed-reset gaps listed in the roadmap.
  The crash opening does not depend on them, because it is a presentation sequence rather
  than a timeline replay.
- The source attribution is currently attached to the whole opening. Milestone 3 introduces
  event-level provenance, and the crash sequence should be folded into that structure so
  individual events carry their own source and uncertainty flags.

## Sources

- **FBI-1** - FBI, *Shooting Incident, 4/11/86 Miami, FL*, Report of Inspector, June 5, 1986.
  BUFile 62-121996. (FBI Vault, Part 1 of 4)
- **FBI-2** - FBI, *William Russell Matix, et al.*, Part 08 (case synopsis and exhibits)
- **MH-1** - *The Miami Herald*, April 12, 1986, "A Reconstruction: The Bloodiest Day in FBI
  History"

See `docs/RESEARCH_crash.md` for the full extraction, the disagreement table, and the
per-source vehicle-role mapping.