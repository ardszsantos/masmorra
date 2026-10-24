# Project guidelines

- Project language pillar: user conversations may be in Portuguese, but all code must be written in English, including comments, documentation comments, identifiers, function and class names, and data structure names. Portuguese code comments are strictly prohibited. Keep player-facing in-game text in Portuguese. Apply this rule to gameplay code, UI code, tests, and supporting scripts.

- Do not interact with Git or remote repositories.
- Keep scope minimal and proportional to the explicit request. Prefer the simplest direct solution; do not add interfaces, dashboards, configurable tools, frameworks, or extra features unless requested or strictly necessary. For example, generating 10 room images calls for a small script that exports 10 images using the existing generator, not an interactive website. If a larger solution seems useful, ask before expanding scope. When the user is only asking about an approach, answer before assuming authorization to build it.
- Before running any tests or validation, always ask the user whether to test and wait for an explicit answer. After finishing implementation, offer the choices "Testar" and "Não testar". This includes automated tests, smoke checks, opening/running the application or browser to verify behavior, and screenshot checks. Never start testing automatically; no response is not authorization. Do not capture or analyze screenshots for validation without explicit authorization.
- Preserve the user's scene structure and art choices. Explain Godot editor steps with exact node names and values.
- Keep input, gesture recognition, character movement, and gameplay abilities separate.
- Abilities granted by items/upgrades must be modular and equip/remove at runtime. Do not embed their rules in the player movement script.
- Expose tuning values in the Inspector. Prototype loadouts belong in scene configuration, not hardcoded player logic.
- Use focused abstractions for current requirements, without implementing speculative inventory or progression systems.
