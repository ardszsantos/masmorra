# Contributor and Agent Standards

These instructions apply to the whole repository. Follow them for code, scenes, resources, tests, and documentation unless a more specific instruction in a subdirectory adds detail. When instructions conflict, follow the user's current request and preserve existing project decisions that request does not change.

## Project pillars

- The user may communicate in Portuguese. All code must be in English: identifiers, class and function names, variables, comments, doc comments, test names, and supporting scripts. Portuguese code comments are strictly prohibited.
- Player-facing text in the game remains in Portuguese. Do not translate UI strings, dialogue, or other game copy into English unless asked.
- Do not use Git or interact with remotes. Do not commit, push, pull, fetch, or change repository history.
- Preserve the existing scene structure, art direction, assets, and gameplay behavior outside the requested change. Do not replace user-provided art with placeholders or redesign unrelated screens.
- Keep the implementation focused on the request. Avoid speculative systems, generic frameworks, redundant configuration, and abstractions that do not solve a current need.

## Code quality

- Write code that a teammate can follow without knowing the whole project. Prefer clear names, short functions with one responsibility, and direct control flow.
- Use object-oriented design where it clarifies ownership and behavior. Keep each gameplay responsibility in the component that owns it; do not move logic into a large all-purpose manager or the player movement script for convenience.
- Use static typing for node references, exported properties, function arguments and return values, and non-obvious local values when practical. Avoid untyped `Variant` values when the expected type is known. Use explicit casts and validate dynamic scene/resource data at boundaries.
- Keep constants and tuning values named. Expose designer-facing gameplay values in the Inspector with sensible defaults and ranges. Avoid unexplained magic numbers and duplicated sources of truth.
- Use signals for meaningful communication between independently owned nodes. Connect and disconnect signals with the component lifecycle; avoid polling another subsystem's state when a signal expresses the event.
- Give nodes and resources clear ownership. Validate nullable or short-lived nodes before use, handle queued-for-deletion nodes, and clean up timers, tweens, temporary effects, signal connections, and physics state when an entity dies, is removed, or changes rooms.
- Do not duplicate an existing shared rule. Room generation behavior belongs in the shared room rules and their adapters; do not fork equivalent logic into UI or gameplay scripts.
- Keep player movement, gesture recognition, and abilities separate. Movement consumes resolved input/ability intent; gesture code recognizes gestures; ability components implement actions.
- Upgrades are modular runtime components. They must support equip, level-up, room context changes, removal, and cleanup of effects they own. Do not embed upgrade behavior in `player.gd`. Configure prototype starting loadouts in scenes, not in hardcoded player logic.
- Keep user-facing copy in Portuguese and code comments in English. Add comments to explain intent, constraints, or non-obvious behavior, not to narrate each line.

## GDScript and Godot

- Target the Godot version declared in `project.godot`. Use APIs supported by that version; do not introduce a plugin or dependency without a clear request and project fit.
- Follow the existing GDScript style: tabs for indentation, `snake_case` for variables and functions, `PascalCase` for classes and node types, and `UPPER_SNAKE_CASE` for constants.
- Prefer `@export` for values that designers should tune and `@onready` for references to nodes in the owning scene. Keep node paths local to the scene and update scene references when renaming nodes or scripts.
- Keep scenes readable and intentionally structured. Do not rebuild stable scene hierarchies in code unless runtime generation is needed. Pair scene/resource changes with the scripts and resource references they require.
- Keep input responsive on touch devices. UI controls must not accidentally consume gameplay input or vice versa. Respect the portrait 720 × 1280 base viewport and test layout assumptions when the user authorizes visual verification.
- Use physics queries with deliberate collision masks, exclusions, and coordinate spaces. Avoid per-frame allocations or full-scene scans in hot paths when a simpler cached or event-driven approach is appropriate.
- Store player-facing text in Portuguese. Keep tuning and reward data in scenes or `.tres` resources when it belongs to designers rather than code.

## Changes and scope

- Before editing, inspect the relevant scripts, scenes, resources, and existing conventions. Find the owner of the behavior instead of patching the first file that appears related.
- Make the smallest complete change that satisfies the request. Do not silently change balance, controls, save formats, asset choices, or neighboring behavior.
- When changing a public method, signal, resource field, node path, or scene contract, update every in-repository caller and dependent scene/resource.
- Avoid absolute machine-specific paths in project files and documentation. Keep new assets under the existing `assets/` organization and reference them with `res://` paths.
- Do not add a test merely to mirror implementation details. For behavior changes, update or add focused tests when they provide meaningful coverage and the user authorizes tests.
- Do not run tests, validation commands, the editor, the game, or screenshot checks without the user's explicit authorization. After implementation, ask whether to **Testar** or **Não testar** and wait before any verification.
- Do not claim that a change works or is verified if it has not been run. In the final report, state what changed and clearly mention any requested checks that were not run.

## Project architecture map

- `scripts/input/`: touch/stroke input and gesture recognition.
- `scripts/abilities/`: player actions and ability lifecycle.
- `scripts/gameplay/`: health, enemies, room assembly and transitions, and rewards.
- `scripts/upgrades/`: modular passive upgrades and their owned effects.
- `scripts/ui/`: menus and HUD components.
- `scenes/` and `resources/`: node composition and designer-authored data.
- `piece-libraries/`: exported room-piece libraries loaded by the game.
- `tests/`: focused Godot test scripts. Run only after explicit user authorization.
