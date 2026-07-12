# Decision: MIT software and CC BY 4.0 content licensing

Date: 2026-07-12

Status: Accepted

## Context

Bean Party is a public, contribution-oriented game repository whose shared shell and independently developed minigames are expected to be forked, modified, and redistributed. Without an explicit license, default copyright restrictions leave contributors and fork authors without clear permission to reuse the project outside GitHub's platform features.

Software and creative game content have different reuse conventions. A single software license would describe code well but would be a poor fit for models, art, audio, and prose. The project also needs clear inbound terms so a contributor understands how an accepted contribution may be reused.

The existing contributors agreed to license their contributions under the terms selected here. The pull request accepting this decision records that consent.

## Options considered

- **No project license** - preserves all rights by default, but conflicts with the project's collaborative fork and contribution model.
- **MIT for the entire repository** - simple and permissive, but uses software-oriented terms for creative content and makes asset attribution less clear.
- **GPLv3 software and CC BY-SA 4.0 content** - keeps distributed derivatives reciprocal, but adds source-distribution and license-compatibility obligations that would increase friction for minigame authors and future platform integrations.
- **MPL 2.0 software and CC BY-SA 4.0 content** - provides file-level reciprocity, but adds per-file boundary and compliance complexity that is not currently justified.
- **MIT software and CC BY 4.0 content** - gives code and project files a familiar permissive software license while giving documentation and media a license designed for attribution and creative reuse.

## Decision

License original Bean Party material using the scope defined in the repository [license overview](../../LICENSE.md):

- Software and project files use the [MIT License](../../LICENSES/MIT.txt). This includes source code, scripts, Godot scenes and resources, project configuration, tests, tools, build and CI files, and code templates.
- Documentation and original creative content use the [Creative Commons Attribution 4.0 International License](../../LICENSES/CC-BY-4.0.txt). This includes models and editable art sources, images, icons, animation, audio, music, narrative text, and similar media.
- Godot-native `.gd`, `.tscn`, and `.tres` files are software even when stored near content. Code examples and snippets embedded in documentation are also MIT unless marked otherwise. A file-specific notice overrides the default category when necessary.
- Third-party material retains its upstream license and must remain identified in the third-party notices or the relevant asset provenance record.
- Copyright remains with each contributor. By submitting a contribution, a contributor represents that they have the right to submit it and agrees to license it under the applicable project license. The project does not require copyright assignment or a contributor license agreement.
- No trademark license is granted for the Bean Party name or branding, and neither project license grants rights in third-party material or branding.

## Consequences

- Contributors and fork authors may use, modify, redistribute, and commercially use covered project material while following the applicable notice and attribution terms.
- MIT permits downstream software forks to remain closed source. CC BY 4.0 permits adaptations under other terms, but the original licensed material and its attribution requirements remain covered by CC BY 4.0.
- Distributions must retain the MIT notice for covered software and provide the attribution, license reference, and change indication required for CC BY 4.0 content.
- Pull requests must confirm that the contributor has the right to submit the contribution and accepts the applicable outbound license.
- Asset catalogs and third-party notices remain necessary because the repository-level licenses do not erase creator-specific attribution or upstream license obligations.
- Packaged Windows test builds include the project license overview, full project license texts, and third-party notices beside the executable.
- Changing these terms for existing contributions later would require the rights necessary to do so; new releases cannot silently revoke permissions already granted under these licenses.
