# Creative and aesthetic direction

Status: Active

## Purpose and scope

This document gives contributors a shared answer to “what should Bean Party feel like?” It translates durable observations about *Bean Battles* into original design principles for Bean Party. It covers visual language, motion, sound, interface, tone, and the relationship between the shared shell and individual minigames.

This is **not** an asset standard. It does not choose exact colors, fonts, meshes, shaders, sound files, import settings, or Godot resources. A future art-and-audio kit should make those choices using the requirements and research questions near the end of this document.

Bean Party is an independent project. Do not copy *Bean Battles* code, assets, branding, characters, maps, interface layouts, audio, text, or identifiable cosmetics. Do not treat screenshots, trailers, or game files as reusable material.

## Reference window and evidence

The primary reference is the recognizable style that began with the 2018 release and was well established by the 2.00–2.07 period in 2020. A detailed player-authored guide describes summer 2020 as the community's peak and records the movement, equipment, tournament culture, and emergent techniques that shaped play. Current official screenshots and the in-game trailer show that the game's main visual grammar remains recognizable: capsule-like players, ordinary low-detail places, oversized equipment and vehicles, a visible closing grid, and a sparse combat HUD.

The evidence base is uneven. Public footage and screenshots support strong visual conclusions. The official store description, achievements, update notes, and a long-running community guide support conclusions about pace, humor, customization, and player culture. Public sources support only a preliminary audio direction; a future asset-standard effort should include a dedicated listening pass and contributor play-memory interviews before prescribing music genres or detailed mix targets.

When evidence and a player's memory disagree, record the version being remembered. *Bean Battles* has changed over time, and “classic Bean Battles” may mean a different patch to different contributors.

## The aesthetic thesis

**Bean Battles feels like an earnest, compact action game whose participants happen to be absurd beans.**

The combat language is straight-faced: familiar weapons, scopes, vehicles, health bars, a minimap, closing-zone pressure, and blunt military or survival-game terminology. The body at the center of it is simple, soft, awkward, customizable, and inherently funny. Neither half works as well alone. Cute beans without the serious competitive frame become generic mascot comedy; realistic combat without the bean becomes a generic shooter.

Bean Party should preserve that productive mismatch while changing the activity. It should feel as though the same kind of scrappy beans have turned ordinary places and objects into overcommitted party competitions.

Use five words as the shortest creative brief:

- **Scrappy:** handmade clarity, simple construction, and energetic imperfection.
- **Earnest:** the game takes the immediate competition seriously even when the premise is ridiculous.
- **Absurd:** scale, bodies, equipment, and consequences do not quite belong together.
- **Kinetic:** players are usually moving, reacting, colliding, or anticipating an impact.
- **Social:** the presentation makes reversals, mistakes, revenge, and narrow wins enjoyable to witness together.

The target is playful intensity, not sweetness, military realism, polished game-show spectacle, or random noise.

## Transferable design grammar

### Characters: simple bodies, loud identities

*Bean Battles* players read first as a vertical capsule, then as tiny feet and attached equipment, and only then as a particular cosmetic identity. This produces a strong silhouette at long range and makes serious gear look disproportionately elaborate.

For Bean Party:

- Start every player character from one original, unmistakably bean-like primary mass with very few anatomical details.
- Keep appendages and facial detail subordinate to the body silhouette. Avoid human proportions, realistic anatomy, and busy surface detail.
- Build identity in layers: player color or pattern, one strong head or face treatment, footwear or another lower-body cue, and an optional activity-specific attachment.
- Make held or worn objects visually simpler than realistic replicas but more mechanically specific than the body. The contrast between “simple bean” and “purpose-built apparatus” is part of the joke.
- Let cosmetics bend the silhouette without hiding the underlying player pose, team, facing, or state.
- Design a new character shape and attachment system. Do not trace *Bean Battles* proportions, reproduce its default face, or recreate a known cosmetic.

At party-game camera distance, player identity must survive motion, overlapping effects, and color-vision differences. Every player needs at least one non-color identifier such as a pattern, icon, number, outline treatment, or stable accessory zone.

### Environments: ordinary places as toy-like arenas

Official media repeatedly uses recognizable, workaday locations—fields, cabins, roads, a small town, warehouses, shipping containers, a snowy settlement, and a desert industrial yard. Geometry is blunt and quickly parsed. Trees, hills, buildings, fences, vehicles, and containers behave more like stage pieces than scenic realism.

For Bean Party:

- Prefer familiar places with one-sentence premises: a yard during a storm, a loading dock at shift change, a picnic overrun by machinery, or a community hall set up for the wrong contest.
- Reduce scenery to large masses, clean routes, bold cover or hazard shapes, and a few memorable landmarks.
- Use small-scale architecture and oversized props to make beans seem simultaneously tiny and capable.
- Let the setting support traversal and jokes. A refrigerator, hay bale, table, or cart should be able to become an obstacle, perch, launcher, vehicle, or objective.
- Keep decorative storytelling at the edges of play. Central routes and timing windows should not depend on texture detail.
- Treat each arena as a deliberately assembled play space, not a naturalistic world slice.

Minigames may use different biomes and premises, but they should share the same economy of form and “ordinary object pushed into competition” logic.

### Shape and material language

The reference favors primitive or low-detail forms, broad uninterrupted surfaces, crisp silhouettes, and modestly glossy or matte-plastic materials. It sometimes combines these with more literal ground textures, smoke, fire, or equipment models. That unevenness contributes to its small-team character, but inconsistency itself is not the goal.

For Bean Party:

- Construct large forms from softened primitives and readable planar shapes.
- Use bevels or rounded edges where they help silhouettes and impacts; avoid uniformly pillowy “cozy game” treatment.
- Keep material families few and legible: bean, painted prop, natural ground, simple structure, transparent hazard, and effect.
- Reserve fine texture and surface noise for non-critical context.
- Favor one strong read per object. A hazard should not need both an elaborate mesh and a busy material to explain itself.
- Preserve deliberate simplicity across contributors rather than imitating accidental technical limitations.

“Low-poly” is a production method, not the complete style. An asset that is low-poly but ornate, moody, realistic, or visually noisy may still be wrong for Bean Party.

### Color, lighting, and contrast

The public screenshots use bright daylight, clear local color, and broad environmental fields: green landscape, tan desert, white snow, blue sky and grid, dark asphalt, and muted buildings. Small saturated accents identify players, pickups, danger, health, and explosions. The result is colorful without covering every surface in equally intense color.

Until a palette is approved:

- Give each scene one dominant environmental family and one secondary structural family.
- Reserve the strongest accents for player identity, interactables, imminent hazards, results, and short-lived effects.
- Use neutral or subdued structures to frame play rather than compete with it.
- Prefer clear daylight or equally legible stylized lighting. If a minigame needs darkness, fog, or colored light, provide redundant silhouettes, outlines, pools of visibility, or UI cues.
- Maintain clear value separation between beans, walkable ground, boundaries, and dangerous space.
- Use red/orange as a likely danger family and green as a likely positive/health family only when shape, icon, text, pattern, or motion also carries the meaning.

Do not sample a palette from screenshots. The future palette should be original, tested in multiple biomes, and evaluated with color-vision simulations and grayscale captures.

### Camera and composition

The reference commonly keeps a bean prominent in a third-person view while leaving enough of the arena visible for routes, approaching danger, and distant opponents. A circular minimap and closing grid provide information that the camera cannot.

Bean Party will often use wider shared-screen cameras, so copy the purpose rather than the framing:

- Keep player silhouettes large enough to read but small enough to show the next decision and likely source of danger.
- Compose around landmarks and playable routes, not scenic vistas.
- Use camera motion to clarify impacts and transitions. Avoid continuous shake or aggressive zoom that makes shared play harder to track.
- Establish camera-distance tiers for the board, shared-arena minigames, close-up minigames, briefings, and results during the future asset-standard pass.
- Test every critical visual at the actual multiplayer camera and output resolution, not only in an editor close-up.

### Motion and impact

The community guide describes mid-air strafing, climbing, parkour, dashes, grenade-assisted movement, and object launches as central to experienced play. Some techniques emerged from collision quirks, but the durable feeling is freedom, momentum, and the possibility that an ordinary object will send a bean somewhere unexpected.

For Bean Party:

- Give idle and locomotion enough body bob, lean, and foot activity to keep the simple body alive.
- Make anticipation, contact, and recovery distinct. A player should see what is about to happen, feel the hit, and understand when control returns.
- Favor short knockback, squash, wobble, spin, stumble, pop, or equipment loss over realistic injury animation.
- Let some props create surprising but learnable movement: bounce, launch, drag, roll, tip, or carry.
- Use brief hit-stop, camera impulse, sound, particles, and pose change as coordinated punctuation; do not solve every impact by adding more particles.
- Recreate the pleasure of emergent movement intentionally. Do not depend on unstable collision bugs or networking latency.

Motion should be slightly more exaggerated than the reference because Bean Party cameras will often be farther away and rounds need spectator clarity.

### Effects and comic violence

Official images show large, simple smoke and fire effects and abstract red fragments rather than realistic wounds. The contrast is forceful but visually unserious.

For Bean Party:

- Keep damage and failure abstract, toy-like, and reversible in tone.
- Prefer bean crumbs, colored chips, stars, dust, paper, puffs, sparks, or activity-specific debris over blood or anatomy.
- Use large effect shapes with short lifetimes and a clean center so players can still locate the cause and result.
- Make hazard categories distinct by silhouette, timing, motion, and sound—not only hue.
- Treat disappearance, respawn, and recovery as comic beats with clear state communication.

The game may be mischievous and slapstick, but it should not be gruesome.

### Interface and typography

The reference HUD is sparse and functional: a strong horizontal health bar, a round/minimap cluster, bottom-center equipment status, white block lettering, and bright state colors. Its menus use dark translucent panels, thin accent lines, tab-like navigation, and dense utilitarian controls. These are useful hierarchy observations, not layouts to reproduce.

For Bean Party:

- Keep in-round UI to the information needed for the next decision: identity, objective, time or progress, score/state, and actionable prompts.
- Use bold, plain, highly legible display type for countdowns, warnings, results, and short labels. Use a calmer companion face for instructions and settings.
- Prefer compact panels, firm edges, and scoreboard-like organization over bubbly toy UI or ornate fantasy frames.
- Use translucent dark surfaces only when they preserve contrast over every supported scene.
- Give major state changes a coordinated visual and audio cue: ready, start, danger, final seconds, finish, placement, reward.
- Scale and simplify beyond the reference. Bean Party must remain legible on a shared display, at couch distance, and during four-player motion.
- Never rely on the exact *Bean Battles* logo treatment, font, red underline, HUD arrangement, icons, or menu composition.

The interface should feel like a competent event system built around an unruly activity, not like a joke interface.

### Sound and music

Available text evidence emphasizes functional, immediate sound: the community guide calls out a loud vocalization during a katana dash, and official update notes discuss the audibility of equipment in flight and after landing. This supports a sound language that communicates cause, distance, danger, and comic action. It does not yet justify a narrow musical genre.

Provisional direction:

- Give movement, pickups, hazards, impacts, scoring, and state transitions distinct, short sonic signatures.
- Combine mechanically informative equipment and prop sounds with occasional bean vocal efforts, reactions, and celebratory noises.
- Keep vocalizations brief enough that repetition remains funny rather than exhausting. Avoid intelligible chatter when a nonverbal sound communicates the state.
- Favor punch, rhythm, and quick decay in busy rounds. Reserve long tails and low-frequency weight for rare major events.
- Make menus and board play social and anticipatory; let minigames increase tempo and density without forcing every activity into the same genre.
- Support separate music, effects, voice, and ambience controls. Important state cues must remain understandable without music and should have visual equivalents.

Before commissioning a shared audio kit, conduct a version-specific listening audit of menu, gameplay, countdown, impact, death, round-end, and spectator states. Record tempo ranges, instrumentation families, dynamic range, repetition tolerance, and accessibility concerns. Create original compositions and recordings; do not imitate a reference track's melody, arrangement, or distinctive sound design.

### Tone, writing, and social feel

The official description is direct and energetic, while achievements mix ordinary competitive labels with mild self-deprecation: a negative score earns “Disgrace,” and a negative kill/death result earns “Target practice.” Player culture then amplifies the premise through bean puns, mock-serious competitive language, dramatic overstatement, tournaments, and stories about exploits.

For Bean Party:

- State rules and objectives plainly. Put humor in the situation, consequence, name, or reaction rather than obscuring instructions.
- Use bean wordplay as punctuation, not as every sentence.
- Let announcer and result language be mock-serious, concise, and aware of reversals without humiliating a real player.
- Celebrate spectacular mistakes as well as skilled wins.
- Encourage immediate rematch and revenge energy, but keep the party competitive rather than hostile.
- Do not import the reference community's in-jokes, user-generated content, edgy chat culture, tournament names, or memes.

The best joke is usually a bean earnestly doing something disproportionate.

## Shared core and minigame freedom

Bean Party should use a shared core with controlled variation, not force every minigame into one scenery pack.

The shared shell should eventually standardize:

- original bean proportions, rig, identity zones, and readable state poses;
- player/team identification and accessibility signals;
- material response and broad geometry/detail budgets;
- common impact, spawn, recovery, countdown, and result grammar;
- UI hierarchy, typography roles, icons, prompts, and transition timing;
- camera-distance categories and readability tests;
- audio buses and shared state cues.

An individual minigame may vary:

- setting, biome, dominant environment colors, and ambient sound;
- activity-specific costumes, props, hazards, vehicles, and effects;
- music genre and tempo within shared mix and transition rules;
- camera within an approved distance category;
- one deliberate visual twist that reinforces its rules.

A minigame stops fitting when its twist hides bean identity, changes the material/detail language beyond recognition, replaces situational absurdity with unrelated spectacle, or requires its own incompatible UI and audio grammar.

## What to preserve, improve, and leave behind

| Preserve the feeling | Improve for Bean Party | Leave behind |
| --- | --- | --- |
| Simple bean-first silhouettes | Four-player and couch-distance legibility | Exact character proportions or faces |
| Ordinary locations turned into arenas | More intentional composition and navigation | Recognizable maps or landmark arrangements |
| Serious equipment on absurd bodies | Original party props and broader non-combat activities | Exact weapons, vehicles, cosmetics, or effects |
| Fast movement and surprising physics | Authored, testable, network-safe interactions | Collision exploits and latency-dependent tricks |
| Sparse competitive information | Accessible hierarchy, scale, prompts, and redundant cues | Exact HUD/menu layouts and typography |
| Blunt, colorful impact punctuation | Clearer cause, effect, recovery, and comfort options | Realistic gore or copied particles/audio |
| Mock-serious social competition | Inclusive humor and celebration of failure | Community memes, slurs, harassment, or copied text |
| Small-team directness | Consistent source files, provenance, and reusable rules | Accidental inconsistency as a style goal |

## Contributor taste test

Before approving a visual, audio, or presentation proposal, ask:

1. Is the player and their state readable at the intended multiplayer camera distance?
2. Does the idea combine a simple bean with an activity, object, or consequence that is amusingly overcommitted?
3. Could someone explain the setting and its main landmark in one sentence?
4. Are the strongest color, motion, detail, and sound accents reserved for gameplay information?
5. Is the impact funny and forceful without becoming gruesome, noisy, or hard to track?
6. Does the interface explain the next decision before it decorates the screen?
7. Would the idea still feel at home beside other Bean Party minigames after its novelty wears off?
8. Is every shipped element original or appropriately licensed, with provenance recorded?

A proposal does not need to resemble a *Bean Battles* screenshot. It should pass the same underlying taste test.

## Requirements for the future standard-asset effort

The later asset project should derive and validate, at minimum:

- a wholly original bean model, rig, animation set, attachment zones, and customization limits;
- a tested player/team identity system with color, pattern, icon, and contrast variants;
- a small original palette system for shell UI, player identity, hazards, rewards, and adaptable biome families;
- licensed font choices, typography roles, numeric styles, localization coverage, and controller glyph rules;
- modular environment primitives, prop scale bands, material families, and geometry/detail budgets;
- shared VFX families for spawn, impact, success, failure, danger, pickup, movement, and recovery;
- UI components for briefing, countdown, objective, timer, score, pause, results, and board rewards;
- camera and lighting reference scenes at every supported distance category;
- shared audio buses, loudness targets, state cues, vocalization limits, and original music briefs;
- accessibility capture tests: grayscale, common color-vision simulations, reduced motion, effects reduction, no-music, and couch-distance review;
- source-file, export, naming, attribution, and Godot import conventions.

That effort should produce comparison boards and prototypes from original work. Reference screenshots may inform discussion but must stay out of shipped assets and should not become paint-over templates.

## Open research questions

- Which patch period do maintainers and early contributors personally remember as definitive?
- Which specific sounds, music states, menu transitions, and round-end cues are essential to that memory?
- How much visual variation should the board and each minigame have before the shared world feels fragmented?
- How far can the original Bean Party body shape depart from the reference while retaining immediate bean readability?
- Which forms of slapstick failure are comfortable for the intended audience and age rating?
- What detail and shader budgets preserve this look on the lowest target hardware once platforms are chosen?

Resolve these through recorded play-memory interviews, original graybox comparisons, and accessibility playtests. An expensive-to-reverse asset-pipeline or content-license choice still requires a decision record.

## Sources

Sources are references for analysis, not sources of reusable assets.

- [Official *Bean Battles* Steam page](https://store.steampowered.com/app/765410/Bean_Battles/) — release information, developer description, official screenshots, in-game trailer, gameplay loop, customization, and current presentation.
- [Official *Bean Battles* achievements](https://steamcommunity.com/stats/765410/achievements/) — names and conditions used to assess the game's competitive and self-deprecating writing tone.
- [Official *Bean Battles* news archive](https://steamcommunity.com/app/765410/allnews/) — versioned evidence for cosmetics, equipment, events, UI changes, audio-relevant equipment behavior, and continuing visual themes.
- [Community “Comprehensive Guide to Bean Battles”](https://steamcommunity.com/sharedfiles/filedetails/?id=1820960790) — player-authored secondary evidence for movement culture, emergent techniques, version history, tournaments, and the community's view of the 2020 period. Treat subjective claims and undocumented mechanics as testimony, not official specification.
- [SteamDB screenshot and metadata record](https://steamdb.info/app/765410/screenshots/) — a secondary index used to cross-check the official media set and trailer identity. SteamDB is not affiliated with Valve or Gupa Games.

## Related documents

- [Game design target](game.md)
- [Minigame contribution contract](../architecture/minigame-integration.md)
- [Godot project architecture](../architecture/godot-project.md)
- [Documentation lifecycle](../README.md)
