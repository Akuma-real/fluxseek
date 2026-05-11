# Add Chinese Communication Instruction

## Goal

Add a persistent project-level instruction telling AI assistants to communicate with users in Chinese.

## Requirements

* Add the instruction to `AGENTS.md` outside the Trellis-managed block so it is not overwritten by future `trellis update` runs.
* Keep the instruction concise and unambiguous.
* Do not modify the Trellis-managed block.

## Acceptance Criteria

* [ ] `AGENTS.md` contains an instruction to communicate with users in Chinese.
* [ ] The new instruction is outside `<!-- TRELLIS:START -->` / `<!-- TRELLIS:END -->`.
* [ ] Existing Trellis instructions remain unchanged.

## Definition of Done

* Change is committed through the Trellis workflow.
* Git working tree is clean after commit.

## Technical Approach

Append a short project-level instruction section after the Trellis block in `AGENTS.md`.

## Out of Scope

* Changing `.trellis/workflow.md` or generated Trellis content.
* Changing application behavior.

## Technical Notes

* The current `AGENTS.md` contains only the Trellis-managed block.
* Line 19 of `AGENTS.md` warns that edits inside the Trellis block may be overwritten.
