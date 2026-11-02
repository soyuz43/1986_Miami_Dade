# Miami Shootout Simulation Prototype Roadmap

## Purpose

Build a first-person-capable, source-aware historical simulation prototype for the April 11, 1986 FBI Miami shootout. It should let someone inspect a reconstruction, replay a selected account, take control of an actor, and compare controlled counterfactuals.

This is a forensic visualization and simulation project, not a conventional score-driven game. The initial goal is not to simulate every detail. It is to make one small, understandable, repeatable slice work from beginning to end.

## Working Principles

- **Start with a visible slice.** Build a simple crash opening before expanding the roster, map, or weapon systems.
- **Separate presentation from simulation.** A scripted opening can establish the crash visually; the event timeline remains the record of simulated events.
- **Keep it deterministic.** The same initial state, timeline, settings, and random seed should produce the same result.
- **Attribute historical claims.** Label a timeline by its source account. Do not present a disputed or approximate detail as settled fact; record uncertainty and competing accounts as the research develops.
- **Use placeholders first.** Primitive meshes, simple colors, and basic controls are enough to test scale and behavior.
- **Add detail only when it serves a test.** Avoid realistic vehicle physics, detailed models, elaborate UI, and complex AI until a smaller version is working.
- **Stay with the project’s actual engine version.** The project was created with Godot 4.7.2; older Godot 4.3 references in the initial notes are obsolete.

## Current Project State

The project already has a useful code foundation:

- Typed resources for weapons, actor profiles, timeline events, and timelines.
- A base actor script with health, ammo, state, damage, and weapon actions.
- Ballistic and wound calculation utilities and result resources.
- A `SimulationManager` autoload and a small test timeline.
- Three weapon resources and two actor profile resources.

There is not yet a main scene, crash scene, environment, or player/overview interface. The existing simulation systems are prototypes, not historically validated models.

### Known Gaps to Address Before Relying on Replay

- The timeline manager currently triggers an event only when its timestamp is within a narrow time window. At higher playback speeds or larger time steps, it can skip events. Seeking changes the clock but does not reconstruct actors into the state they should have at that time.
- Random number generators exist in the actor and ballistic code, but a coordinated reset/seed policy is still needed for identical reruns.
- `MOVE_TO` currently changes an actor’s position immediately rather than moving them over a duration.
- The ballistic solver currently uses a simple barrier value and randomized hit location; it does not yet raycast through multiple scene barriers.
- Timeline-level source labels exist, but individual event provenance and uncertainty are not yet represented.
- Weapon and wound values are prototype inputs. They should not be treated as validated historical or medical conclusions without supporting sources.

## Roadmap

### Milestone 1 — Launch Directly Into a Graybox Crash (COMPLETE)

**Goal:** Pressing Play opens the crash sequence without a menu or setup screen.

- Create a minimal `scenes/main.tscn` and a crash/blockout scene.
- Use simple road geometry and box-shaped vehicles; choose a camera viewpoint that is clear and consistent with the intended first-person experience.
- Animate a short approach, impact, and settling moment with keyed transforms. Use an `AnimationPlayer` or similarly controlled sequence rather than trying to make a physically accurate crash on the first attempt.
- Let the player inspect or control the scene after the vehicles settle. Initially, a fixed camera is acceptable; full actor possession can come later.
- Add a reliable restart so the opening can be repeated.

**Done when:** Running the project immediately shows the same understandable crash sequence, ends in the same positions, and can be restarted. Primitive shapes are sufficient. The camera is a visualization choice, not evidence that an actual camera view existed.

**Status:** Complete. Pressing Play opens the crash sequence directly. The opening is a
deterministic, keyframed animation of the pursuit and crash on Southwest 82nd Avenue, built
from the sources documented in `docs/RESEARCH_crash.md`. `R` restarts the opening and `C`
toggles the camera. See `docs/MILESTONE_1.md` for the implementation notes, the assumptions
made, and how to verify it.

### Milestone 2 — Make Time and Replay Reliable

**Goal:** A short sequence of timeline events plays once, in order, and can be repeated.

- Fix event dispatch to detect timestamps crossed between simulation updates, rather than requiring the clock to land close to an event timestamp.
- Define event ordering for events with equal timestamps and ensure each event executes exactly once per run.
- Specify what pause, speed changes, reset, and seek mean. For early development, reset-and-replay from the beginning is preferable to pretending arbitrary seeking works before actor-state reconstruction exists.
- Centralize random-seed handling and reset it at the start of each replay.
- Add a simple event log showing simulation time, actor, event, and result.

**Done when:** A small test timeline produces the same ordered log and actor state on repeated runs at normal and faster playback speeds. Reset is reliable; unsupported seek behavior is clearly disabled or limited.

### Milestone 3 — Build One Source-Labeled Historical Slice

**Goal:** Connect the crash scene to a short, researched sequence after the impact.

- Choose a bounded passage that can be checked against the sources available to the project; include only the actors, vehicles, and events needed for that passage.
- Store the passage as a timeline resource and label its account/source. Treat the initial FBI account as one source-backed reconstruction, not as an unquestionable canonical truth.
- As research grows, add event-level source notes, page/diagram references, confidence, and disputed/unknown status rather than burying those distinctions in code.
- Keep a clear separation between what a source reports, what the simulation assumes, and what the model calculates.

**Done when:** The selected passage plays in the graybox scene, its events are visible in the log, and a reviewer can tell which source or assumption supports each important event.

### Milestone 4 — Improve the Blockout and Actor Movement

**Goal:** Make positions and movement understandable enough to evaluate the selected passage.

- Refine only the relevant part of the road/intersection and nearby landmarks using diagrams, photographs, and other documented materials as available.
- Document the coordinate axes, units, estimated dimensions, and uncertain placements. Treat coordinates as adjustable estimates until corroborated.
- Add only the vehicles and actor profiles required by the selected slice; expand the roster when later events require them.
- Replace instant position changes with time-based movement where the timeline needs movement. Keep the crash animation separate if it is a fixed opening presentation.

**Done when:** A viewer can understand where the relevant actors and vehicles are, which movements occur, and which placements remain uncertain.

### Milestone 5 — Refine Weapons, Barriers, and Wounds

**Goal:** Make shot outcomes inspectable and tied to the scene, without claiming more precision than the model supports.

- Add scene raycasts from the appropriate firing point and identify barriers along the shot path.
- Model penetration across multiple barriers and preserve the reason a shot was blocked or passed through.
- Make hit-location randomness reproducible and configurable; separate random model outcomes from fixed historical events when an account specifies an observed outcome.
- Expand injury behavior only when needed by a sourced scenario. Represent uncertain or disputed injury details as assumptions or alternatives, not as special-case “historical” rules.
- Log each shot’s shooter, weapon, target, barriers, hit result, and model settings.

**Done when:** A small number of test shots produce repeatable, inspectable results, and the log explains the model’s decision. The model is described as an approximation unless validated against evidence.

### Milestone 6 — Add Actor Possession

**Goal:** Let the user intervene without silently corrupting the baseline replay.

- Start with an overview selection method and switch the camera to the selected actor.
- Add only the basic movement and interaction controls needed to test the scenario.
- Define timeline ownership: when an actor is possessed, that actor’s scripted events are paused or overridden while the other actors continue according to a clearly specified rule.
- Record player interventions as a separate branch or run log so the baseline remains unchanged.

**Done when:** The user can take control of one actor, intervene, return to overview, and compare the resulting run with the untouched baseline.

### Milestone 7 — Compare Accounts and Counterfactuals

**Goal:** Make differences between sources and user changes explicit.

- Add another source-labeled timeline only after the first timeline format and replay behavior are reliable.
- Provide a basic comparison of event timing, positions, shots, and outcomes between runs.
- Add a small, controlled set of counterfactual options—such as a loadout, starting position, or event timing—and record exactly which settings changed.
- Keep each run’s timeline, seed, settings, and outcomes together so results can be reproduced.

**Done when:** A user can identify what changed between a baseline and a comparison run and reproduce both runs from their recorded inputs.

## Deliberately Deferred

Until the earlier milestones work, do not prioritize detailed character or weapon models, complex animations, full-scene art, sophisticated AI/perception, a complete historical event timeline, pellet-by-pellet ballistics, elaborate menus, or extensive UI. These may be useful later, but they do not prove that the core simulation works.

## First Practical Steps

1. Create the minimal main scene and a graybox road with placeholder vehicles.
2. Add the repeatable crash sequence and a restart action; verify it by running the project.
3. Once the opening works, connect a short test timeline and make its event log deterministic before adding more historical events.

## Long-Term Success Criteria

The prototype is successful when it can:

- Start in the crash opening and replay a selected, source-labeled historical passage reliably.
- Show actors, vehicles, event timing, and shot outcomes in a spatially understandable scene.
- Make assumptions, uncertainty, and account differences visible rather than hiding them.
- Allow actor possession and controlled counterfactual runs without overwriting the baseline.
- Reproduce a run from its timeline, settings, and random seed.

“Every shot matches the historical record” is not a useful early acceptance criterion: accounts may differ, evidence may be incomplete, and model outputs are approximations. The tool should instead show what source supports an event, what assumptions were made, and how the simulation reached its result.
