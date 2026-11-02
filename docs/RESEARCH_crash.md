# Milestone 1 Research Brief — The April 11, 1986 Vehicle Crash

**Scope:** This brief documents only the vehicle-stop and crash sequence that opens the simulation.
It does not cover the gunfight itself (that is Milestone 3's subject).

**Purpose:** Milestone 1 builds a graybox animation of the crash. This brief supplies the
event sequence, the vehicle roles, and the disputed points, so the animation can be labeled
honestly rather than presented as a settled reconstruction.

---

## Sources Consulted

| ID | Source | Type | Notes |
|----|--------|------|-------|
| **FBI-1** | FBI, *Shooting Incident, 4/11/86 Miami, FL*, Report of Inspector, June 5, 1986. BUFile 62-121996. (FBI Vault, Part 1 of 4) | Primary — official investigative report | Narrative of the shooting incident and radio traffic transcript |
| **FBI-2** | FBI, *William Russell Matix, et al.*, Part 08 (case synopsis with Exhibits) | Primary — official case file | Detailed vehicle-stop narrative and Exhibit A reference (final vehicle positions) |
| **MH-1** | *The Miami Herald*, April 12, 1986, "A Reconstruction: The Bloodiest Day in FBI History" | Secondary — contemporaneous news reconstruction | Detailed physical description of the pursuit and collisions; explicitly labeled a reconstruction |

**Note on source hierarchy:** FBI-1 and FBI-2 are official investigative findings. MH-1 is a
newspaper reconstruction assembled from FBI agents, eyewitnesses, and a tape of agent radio
conversations obtained by the Herald. MH-1 adds physical detail that FBI-1 omits (specific
trees, posts, fences, vehicle colors), but it is not an official determination.

**Not consulted:** Exhibit A (the official diagram of final vehicle positions) and the aerial
photographs are referenced in FBI-1/FBI-2 but are images within the released PDF pages. They
were not transcribed for this brief. Any spatial reconstruction in the simulation is therefore
an *estimate derived from written description*, not a transcription of the official diagram.

---

## The Vehicle Roles

| Vehicle | Occupants | Description | Source |
|---------|-----------|-------------|--------|
| **Suspect vehicle** | Michael Lee Platt (driver), William R. Matix (passenger) | 1982 Chevrolet Monte Carlo, black two-door, FL tag NTJ-891. Stolen March 12, 1986. | FBI-1, FBI-2, MH-1 |
| **FBI Car C** | SA Benjamin Grogan (driver), SA Jerry Dove (passenger) | Buick Century, described by MH-1 as lemon-yellow with a brown roof. Initiated the felony car stop. | FBI-1 (roles confirmed), MH-1 (color) |
| **FBI Car A** | SA John F. Hanlon Jr. (driver), SA Edmundo Mireles Jr. (passenger) | Chrysler, described by MH-1 as gold, 1983 model. | FBI-1 (roles confirmed), MH-1 (make/color) |
| **FBI Car B** | SA Richard A. Manauzzi (driver) | Buick, described by MH-1 as gray. Performed the decisive ram. | FBI-1 (role confirmed), MH-1 (color) |
| **FBI Car D** | SSA Gordon McNeill (driver) | Position: came into the area after the crash, per FBI-1. | FBI-1 |
| **FBI Car E** | SA Ronald Risner (driver), SA Gilbert Orrantia (passenger) | Arrived after the crash; staged on the west side of 82nd Avenue. | FBI-1, FBI-2 |

**Disputed vehicle labeling:** FBI-1 uses letter designations that shift between passages
(e.g. one passage calls McNeill's car "Vehicle D" while another calls Grogan and Dove's car
"Vehicle D"). FBI-2 refers to "Exhibit A" for final positions. The letter labels are **not
used in this brief or the simulation** to avoid propagating an internal inconsistency.
Vehicles are referred to by occupant names instead.

**Note on the Mini-14:** FBI-1 concludes the Mini-14 rifle was carried by Platt. MH-1 reports
that agents at the scene identified the Mini-14 carrier as Matix, and explicitly notes the
identification remained in doubt. The FBI ballistics (FBI-1) is the stronger evidence and is
what the simulation should follow, but this is a **known disputed point**.

---

## The Sequence

### Phase 1 — Surveillance (before the crash)
- ~8:45 a.m. — 14 SAs in 11 automobiles begin area surveillance along South Dixie Highway
  (U.S. 1), roughly 130th to 183rd Street, covering five banks. (FBI-2)
- ~9:26 a.m. — Grogan radios that he is behind a black Monte Carlo, tag NTJ-891, northbound
  on South Dixie Highway. (FBI-2, FBI-1)
- ~9:30 a.m. — Grogan/Dove are joined by three additional FBI units. All units are now in a
  residential neighborhood, several blocks off the commercial strip. (FBI-2)
- The subjects, aware of the surveillance, drive erratically, apparently attempting to set up
  a break-out escape. McNeill observes them loading weapons and transmits this. (FBI-2)
- MH-1 places the felony car stop at **9:19 a.m.**, and says the gunfight began at **9:20 a.m.**
  MH-1 also places the subjects' turn onto SW 117th Street before the stop. (MH-1)
- FBI-2 places the stop at **~9:32 a.m.** near the intersection of Southwest 122nd Street.
  (FBI-1 also cites "approximately 9:32 a.m.") (FBI-1, FBI-2)

> **Uncertainty — timing.** The FBI files and the Herald reconstruction disagree by roughly
> 13 minutes on the moment of the car stop (≈9:32 vs ≈9:19). This is an unresolved
> discrepancy between the official account and the newspaper account. The simulation should
> not assert a wall-clock time. It should label the sequence by **relative** phase
> (approach → stop → ram → impact → settle) and, where a time is shown, mark it as
> account-dependent.

### Phase 2 — The felony car stop
1. Grogan orders the stop: *"Felony car stop, take them, felony car stop, let's do it."*
   He engages lights and siren. (FBI-2; MH-1 quotes the same wording)
2. The pursuit is traveling **south** on 82nd Avenue, in the 122nd block. (FBI-2)
3. The suspect vehicle swerves right, brakes, and leaves the pavement. (FBI-2)
4. **Manauzzi** (Car B, coming from behind) observes the passenger preparing to fire on the
   overtaking FBI vehicles and **rammed the Monte Carlo** to incapacitate the occupants. (FBI-2)
5. **Hanlon** (Car A) swung his unit abreast of the suspect vehicle and **rammed it** to stop it.
   (FBI-2)
6. Resulting repeated ram/counter-ram causes the loss of control of the FBI vehicle, and its
   collision with a **retaining wall on the west side of 82nd Avenue**. (FBI-2)

### Phase 3 — The U-turn
7. The subjects attempt to evade by negotiating a **high-speed U-turn**, heading back north on
   82nd Avenue. (FBI-2)
8. Manauzzi, momentarily stopped by the earlier impact, observes the suspect vehicle returning
   in his direction and **rammed it a second time**, terminating the vehicle stop effort. (FBI-2)

### Phase 4 — Impact and final position
9. **FBI-1's account of the final position:** The suspect's vehicle came to rest **facing northbound
   in the parking area of a front yard at 12201 Southwest 82nd Avenue**. It was **wedged between a
   parked civilian vehicle, an FBI vehicle and a tree**, and **flanked by two FBI vehicles**.
   FBI-1 also states that the suspect's vehicle was "pinned between MM-66, a tree and a parked
   automobile **in a yard in front of the residence 12201, 12203 Southwest 82nd Avenue**."
   Two FBI vehicles were parked unoccupied in that residence.
10. **FBI-2's account:** Subject's vehicle came to rest **between the tree and the parked
    automobile directly in front of the subjects**, with **Vehicle C (Manauzzi)** behind it.
    **Vehicle E (McNeill)** turned into the area; **Vehicle D (Grogan/Dove)** made a U-turn and
    parked to the rear of the subject's vehicle. (FBI-2)
11. **MH-1's account:** As the Monte Carlo rocketed north up the street, **Manauzzi rammed it hard
    on the driver's side. The two cars careened up and over the sidewalk and slammed into a
    20-year-old bottlebrush tree. They had traveled maybe 30 yards, locked together.** Matix
    could not open his door because it was wedged against a **shiny black Cutlass parked in the
    driveway**, belonging to resident Cory Sukert. (MH-1)
12. **Additional MH-1 detail:** Platt swerved the Monte Carlo right, **bashing Hanlon's gold
    Chrysler on the left front quarter panel and driver's door**. Both cars rebounded and spun out
    of control. The Chrysler **knocked down a three-foot post, took out a spindly melaleuca tree,
    and slammed into the wall of a Florida Power & Light substation**. The Monte Carlo **went up
    onto the grass in the same direction and uprooted another melaleuca**. Platt yanked the wheel
    into a sharp left turn to complete the U-turn and **hit another thick three-foot post**, which
    split the radiator; green radiator fluid spewed out. The Monte Carlo stopped. Platt tried to
    restart it. Grogan made a U-turn ~30 yards down the road; Manauzzi did the same in the
    driveway of **HOW** (a residence, referred to by its occupants' initials). (MH-1)
13. **Impact damage:** FBI-1 notes that the subjects' vehicle **impacted once again into the
    driver's side**, pinning it between the parked car, tree and Manauzzi's vehicle. FBI-1 also
    records that **laboratory paint examinations show FBI vehicles also impacted with each other**
    during the attempted stop. (FBI-1)

### Phase 5 — The gunfight begins (context only; not built in Milestone 1)
- FBI-1: "As the vehicles came to a halt, SA Manauzzi's vehicle was directly alongside the
  subjects' vehicle. SA Manauzzi was immediately taken under fire." The subjects fired from
  within the vehicle before agents could fully exit. (FBI-1, FBI-2)
- Manauzzi's revolver, resting beside him on the seat, was knocked to the floor during the
  crash. He exited unarmed and took cover behind a wall on the west side of 82nd Avenue. (FBI-1)
- Hanlon's revolver likewise went to the floor during the impact; he fought with a five-shot
  snub-nosed revolver from an ankle holster. (FBI-1)
- Hanlon and Mireles exited their vehicle (which had struck the wall) and crossed the street
  to assist. (FBI-1)
- The subject vehicle's **driver's door was jammed** against the parked Cutlass. (MH-1)

---

## Where the Sources Disagree

| Point | FBI-1 / FBI-2 | Miami Herald (MH-1) | Status |
|-------|----------------|----------------------|--------|
| **Time of car stop** | ≈9:32 a.m. | ≈9:19 a.m. | **Unresolved.** ~13-minute gap between official account and newspaper account. |
| **What stops the subject car** | Manauzzi rammed first, Hanlon rammed, then Manauzzi rammed again after the U-turn | Hanlon pulled alongside, Platt swerved into Hanlon, then Manauzzi rammed the driver's side | **Partially compatible.** Both accounts have Manauzzi's second ram as decisive and both have Hanlon involved, but they differ on the initiating contact. FBI-2 places Manauzzi's first ram *before* Hanlon's. |
| **Identity of the tree struck** | "a tree" | 20-year-old bottlebrush tree | MH-1 is more specific. Consistent. |
| **Where the Monte Carlo came to rest** | "in the parking area of a front yard" / "in a yard in front of the residence 12201, 12203 SW 82nd Avenue" | over the sidewalk, locked together with Manauzzi's car, against the Cutlass in the driveway | Broadly compatible: a residential front yard/driveway with a parked civilian car and a tree. **Exact geometry differs.** |
| **Manauzzi's vehicle at rest** | FBI-2: behind the subject vehicle; FBI-1: "directly alongside" | "locked together" against the tree | Compatible. |
| **Hanlon/Mireles vehicle impact** | "came to rest against a wall on the west side of 82nd Avenue" | "slammed into the wall of a Florida Power & Light substation" | Compatible; MH-1 identifies the wall's owner. |
| **Mini-14 carrier** | Platt (FBI-1, FBI-2) | Agents at the scene identified Matix; MH-1 notes the ID was in doubt | **Disputed.** Follow the FBI ballistics, flag the dispute. |
| **Total rounds fired** | FBI-1: "approximately 145" in the summary, "minimum of 131 and as many as 140-145" in the narrative, ~131 identifiable. FBI-2: "approximately 143" | not addressed | FBI-1 itself is internally inconsistent. Out of scope for Milestone 1. |
| **Grogan/Dove vehicle position at rest** | FBI-2: parked to the rear of the subject vehicle, after making a U-turn | Photo caption: put in behind Manauzzi's car | Compatible. |

---

## What This Means for the Simulation

### Spatial model
- Coordinate system: **X = east, Z = south** (Godot's default: -Z is north/forward, +Z is south).
  The road runs north-south along 82nd Avenue, so the road is a strip along the **Z axis**.
  The subject vehicle travels **southbound** at the stop, then performs a **U-turn** to northbound.
- The subject car ends **facing northbound** (FBI-1 is explicit on this), wedged in a residential
  front-yard/driveway on the **west side of 82nd Avenue**, against a **tree** and a **parked
  civilian car**, with **Manauzzi's FBI car** in contact and **two other FBI cars flanking**.
- The Hanlon/Mireles FBI car comes to rest against a **wall on the west side** of 82nd Avenue,
  slightly south of the subject vehicle.
- Grogan/Dove's car is **behind (south of)** the subject vehicle after a U-turn.
- Risner/Orrantia's car arrives and stages on the west side, north-west of the scene.

These are the **only** spatial facts with reasonable support. Everything else — exact distances,
driveway depth, which side of the street the front yard is on — is an estimate.

### Animation structure (Milestone 1)
Deterministic, keyframed, no physics. Phases:
1. **Approach** — all four vehicles southbound on 82nd Avenue at ~35 mph (MH-1).
2. **First ram** — Manauzzi's car contacts the Monte Carlo's driver side.
3. **U-turn** — the Monte Carlo swings around to face northbound.
4. **Second ram** — Manauzzi's car hits the driver's side again; the pair go over the sidewalk
   and strike the tree and the parked civilian car.
5. **Settle** — vehicles come to rest in the documented final arrangement; the Hanlon/Mireles
   car slides to the wall; Grogan/Dove swings around behind.

### Labeling requirements
- The HUD must state that the scene is a **blockout reconstruction** and that spatial layout is
  **estimated from written sources**, not from the official Exhibit A diagram.
- The time shown must be marked **account-dependent** or omitted.
- The simulation must not present the disputed Mini-14 attribution as settled (not directly
  relevant to Milestone 1, but the same labeling discipline applies).
- The camera is a **visualization choice**. There was no camera in the actual event.

### Explicitly not modeled in Milestone 1
Radiator fluid, post/bollard impacts, tree species, vehicle paint, glass breakage, injuries,
the gunfight, and the 143-145 round count. These belong to later milestones.
