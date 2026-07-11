# Game design target

## The short version

Bean Party should be a social board game where a turn-based board creates anticipation and short minigames create the memorable moments. The target is the *structure* that makes Mario Party-style games work, not Nintendo’s characters, art, rules text, boards, or minigames.

Nintendo describes Super Mario Party’s board mode as players taking turns rolling dice and racing across a board, with a varied set of free-for-all and team minigames. That is useful reference for the genre’s cadence, variety, and social readability. [Nintendo’s overview](https://www.nintendo.com/us/store/products/super-mario-party-108391/) also highlights online and local play, reinforcing that the shared experience matters as much as any individual challenge.

## Design pillars

1. **The board frames the party.** Players need choices, routes, risks, rewards, and occasional reversals between minigames. The board makes each minigame result matter beyond a single round.
2. **Minigames are quick and legible.** A player should understand the objective before play starts, use a small control vocabulary, and see a clear outcome. Aim for 30–90 seconds of active play before results.
3. **Every player stays involved.** Prefer designs where players can recover, influence the outcome until late, or enjoy the spectacle even after falling behind. Eliminate long waits and unclear failure states.
4. **Variety creates stories.** Support free-for-all, 2v2, 1v3, and cooperative formats. Rotate between precision, movement, bluffing, observation, timing, and controlled chaos rather than repeatedly using the same skill.
5. **The party is competitive, not hostile.** Surprises, reversals, and playful disruption are welcome. They should be understandable, rare enough to stay special, and never erase player agency without a chance to respond.
6. **Bean Party gives the game its identity.** The board economy, characters, announcer language, props, environments, and results must be original and Bean Battles-inspired rather than Mario Party replicas.

## Core-loop hypothesis

This is a starting hypothesis to test, not a locked rule set:

1. Players enter a board with an explicit objective and a visible lead state.
2. Each player makes a compact turn decision: move, choose a route, spend a resource, or accept a risk.
3. A trigger selects a minigame format based on the board state.
4. The minigame awards beans, board advantages, or both.
5. The board translates those rewards into progress toward a final win condition.

The design work should answer two questions early: what does a bean mean in the board economy, and what decision does a player make because they have one?

## Minigame target

The initial compatibility target is 2–4 local players using a shared screen and controllers or keyboard. Online play follows the same 2–4 player target ([networking architecture](../architecture/networking.md)). More players and asynchronous modes may follow, but should not complicate the first slice.

Use the [minigame design guide](minigames.md) for proposal requirements, review criteria, the implemented design brief, and the minigame design definition of done.

## Boundaries

- Make original boards, names, objectives, art, sound, text, and mechanics. “Inspired by” never means copying a known minigame with a visual swap.
- Prefer an accessible, local-first prototype over a feature-complete board system.
- Do not treat combat, weapons, or chaos as mandatory in every minigame. They are seasoning for Bean Party's Bean Battles-inspired tone, not a substitute for a clear objective.

## Questions to test in a first playable

- Does a 30–90 second minigame feel rewarding after a board turn?
- Does the board give winners an advantage without making the match feel decided too soon?
- Can newcomers understand a minigame from one instruction card and a five-second demonstration?
- Which Bean Battles-inspired visual motifs improve readability rather than obscure it?
