# Use and contribute standard assets

The standard asset kit gives contributors canonical early building blocks without presenting them as final production art. Read the [creative direction](../design/creative-direction.md), [asset pipeline decision](../decisions/0005-standard-asset-pipeline.md), and [asset catalog](../../assets/standard/catalog.md) before creating a similar shared asset.

## Lifecycle states

- **Canonical prototype** - reuse this asset by default today. It is intentionally replaceable and does not represent final production quality.
- **Candidate** - available for comparison or testing, but not the default dependency for new work.
- **Deprecated** - do not add new uses; follow its catalog replacement note.

If a canonical asset almost fits, prefer a parameter, material variant, wrapper, or focused improvement over a second shared copy. Keep genuinely minigame-specific work inside that minigame. Propose promotion when an asset becomes a real cross-minigame need.

## Layout and naming

```text
assets/
  source/standard/       # Editable sources; hidden from Godot by .gdignore
  standard/              # Runtime GLB, SVG, Godot materials, themes, and catalog
```

Use lowercase kebab-case filenames and stable descriptive IDs. Do not put a prototype version in a canonical file path; record its lifecycle/version in the catalog so a reviewed replacement does not require consumers to rewire paths.

Every catalog entry records its purpose, runtime path, editable source when applicable, status, authoring tool/version, and provenance. Third-party material additionally requires creator, source URL, and license. The initial kit is entirely original project work. The repository still has no content license, so do not assume these assets are reusable outside Bean Party.

## Approved bean prototype target

The current `bean-static-prototype` was reviewed on 2026-07-12. Its `.blend`, `.glb`, repeatable Blender generator, gallery presentation, and geometry tests implement the approved static target below. Earlier egg-shaped studies with arms, oval feet, and a mouth are deprecated and must not be restored or used as character references.

Use these measurements for the replacement prototype:

| Element | Approved prototype construction |
| --- | --- |
| Body | `0.32 m` radius, `0.75 m` constant-width cylinder, hemispherical caps, and approximately `1.39 m` total body height |
| Rest curve | Source-local facing `-Y`, both ends forward of the middle; centerline offset `y = 0.07875 × 16t²(1-t)²`, where `t` runs from bottom `0` to top `1`; the export orientation maps this to Godot `-Z` forward |
| Eyes | White oblate hemispheres approximately `0.090 × 0.044 × 0.078 m`, centered near `x = ±0.070 m`, with black circular pupils approximately `0.028 m` across |
| Face | No mouth and no other default facial geometry |
| Upper limbs | No arms or hands; equipment uses reviewed body-side, equipment, or costume anchors |
| Lower limbs | Two short shins extending into both the body and shoe collars; the reviewed prototype spans approximately `z = 0.13–0.37 m` |
| Shoes | Slim, low wedge shoes with recognizable heel, sole, toe, and slight outward rotation; no lighting-visible ankle gap |

These values capture the approved static silhouette, not final rig constraints. A future rig may straighten or bend the body backward for actions such as looking up, but its neutral pose returns to the shallow forward-facing C. Keep the existing four body colors and separate geometric badges for player differentiation.

## Blender handoff

The initial 3D source and byte-for-byte freshness check require Blender 5.1.2. The runners discover `BLENDER_BIN`, a `blender` command on PATH, and common Windows installation locations. Pinning the exact version avoids noise-only GLB differences caused by exporter changes.

Build the approved source and runtime export:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\assets.ps1 build
```

Export an edited `.blend` source or verify that the committed GLB is current:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\assets.ps1 export
powershell -ExecutionPolicy Bypass -File .\tools\assets.ps1 check
```

On macOS or Linux, use `bash tools/assets.sh build`, `export`, or `check`. Set `BLENDER_BIN` when Blender is outside the runner's normal discovery paths. Any future Blender version upgrade must be tested by rebuilding, importing in Godot 4.7, comparing the visual result, and updating the decision and recorded authoring version before relaxing the pin.

## Inspect the kit

Open `res://scenes/dev/standard_asset_gallery.tscn` and run it as the current scene with `F6`. The gallery is contributor-only and is not part of the shipped app flow.

- `1` selects the close camera.
- `2` selects the shared-arena camera.
- `3` selects the board-distance camera.
- `G` toggles grayscale on the 3D scene for a redundant-cue check; the UI legend remains in the canonical source colors.

Check the character, badge, and identity at the intended multiplayer distance rather than only close up. The four identities deliberately pair color with circle, triangle, square, and diamond silhouettes. Their current colors are color-vision-conscious candidates, not a claim that color alone is sufficient.

The gallery demonstrates the approved static bean geometry alongside the identity palette, badges, materials, camera distances, and grayscale control. It does not demonstrate future rigging, animation, attachment behavior, or final production quality.

## Before submitting a change

1. Update the editable source and runtime export together.
2. Update the catalog and provenance when status, purpose, source, or authoring version changes.
3. Run the asset export check and `tools/godot.ps1 all` or `bash tools/godot.sh all`.
4. Inspect normal and grayscale gallery captures at all three camera distances.
5. Include player-facing effect, visual evidence, source/provenance, and known prototype limitations in the pull request.
