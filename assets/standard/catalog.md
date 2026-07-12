# Standard asset catalog

All entries in this initial catalog are original work created for Bean Party. The repository has not selected a content license; inclusion here does not grant reuse outside the project. See [Use and contribute standard assets](../../docs/guides/standard-assets.md) for lifecycle and contribution rules.

| Asset ID | Status | Canonical runtime path | Editable source | Purpose and provenance |
| --- | --- | --- | --- | --- |
| `bean-static-prototype` | Canonical prototype | `characters/bean-static-prototype.glb` | `../source/standard/characters/bean-static-prototype.blend` | Original static character and scale reference, authored with Blender 5.1.2 and rebuilt to the approved 2026-07-12 geometry: curved hemisphere-capped cylinder, oblate eyes, no mouth or upper limbs, intersecting shins, and slim shoes. |
| `player-circle` | Canonical prototype | `identities/player-circle.svg` | Same SVG | Original circle identity badge, hand-authored for this kit. |
| `player-triangle` | Canonical prototype | `identities/player-triangle.svg` | Same SVG | Original triangle identity badge, hand-authored for this kit. |
| `player-square` | Canonical prototype | `identities/player-square.svg` | Same SVG | Original square identity badge, hand-authored for this kit. |
| `player-diamond` | Canonical prototype | `identities/player-diamond.svg` | Same SVG | Original diamond identity badge, hand-authored for this kit. |
| `identity-materials` | Canonical prototype | `materials/identity-*.tres` | Same Godot resources | Four rough, nonmetallic identity material variants authored for this kit. |
| `prototype-theme` | Canonical prototype | `ui/prototype-theme.tres` | Same Godot resource | Limited shell background, surface, divider, and text variations. It deliberately does not establish final controls, fonts, or UI components. |

## Approved bean implementation

The editable source, GLB export, repeatable Blender generator, comparison gallery, and geometry tests now implement the approved static target. It keeps the existing asset ID and paths so consumers receive the replacement without rewiring. See the [approved bean prototype target](../../docs/guides/standard-assets.md#approved-bean-prototype-target) for measurements and the boundary between this static prototype and a future rig.

## Identity mapping

| Join order | Identity | Color |
| --- | --- | --- |
| 1 | Circle | `#56B4E9` |
| 2 | Triangle | `#E69F00` |
| 3 | Square | `#009E73` |
| 4 | Diamond | `#CC79A7` |

`PlayerIdentityConstants` is the resource-free runtime source of truth for identity IDs and serialized colors. `StandardVisuals` maps those values to icons and materials without making the match/network layer load presentation resources. `PlayerSlot.slot_color` remains the serialized/networked value; the badge shape is derived locally without changing the wire format.
