# WhekeOS Agent Directive

## Authority

The project owner defines the standard.

Codex must not guess the architecture, naming, visual standard, security posture, operating environment, or completion level.

If required information is missing, ask before changing files.

Do not rename.

Do not assume.

Do not simplify the owner’s intent.

Do not downgrade the visual standard.

Do not substitute generic Linux behaviour for WhekeOS behaviour.

## Mission

WhekeOS is a Māori-led, offline-first, defensive, headless T-UI bootloader environment for local-first digital independence.

This repository is not a toy shell demo, not a generic Linux script, not a placeholder animation project, not a branding exercise, and not a web app.

The work here is for a high-end boot display and bootloader flow inside a proot-distro Alpine root environment.

Codex must preserve the last working version and develop forward from it.

## Operating Environment

Target environment:

- proot-distro Alpine
- root shell
- Termux host compatibility where practical
- POSIX `/bin/sh`
- headless terminal
- offline-first
- no cloud dependency
- no internet dependency
- no GUI dependency
- no browser dependency
- no systemd dependency

Design and patch for Alpine root first.

Do not design primarily for desktop Linux, Ubuntu, Debian, or Android outside the Alpine/proot context.

## Source Script Rule

The active source script is `codex_example` in this directory.

Patch the EOF-generated script flow in `codex_example` only when asked to change the boot/runtime implementation.

Do not treat the temporary Termux `Whakaahua` tree as the Alpine runtime tree.

The Alpine runtime target is `/opt/mdi`.

## Asset Contract

Use only the real assets already present in this directory:

- `MDI(1).jpg`
- `Lock.png`
- `Whekeos.png`
- `Owl1.jpg`

Do not invent alternate filenames.

Do not use placeholder art.

Do not reference missing files.

## Boot Contract

Required boot order:

1. MDI
2. Kaihaumaru
3. WhekeOS
4. Interface handoff

Boot must remain staged, isolated, and deterministic.

Each stage must clear before the next stage begins.

The final handoff prompt is:

`rangatira@maori_dev~$`

## Language Policy

- Te Reo Māori for boot logos and MDI-related integrations.
- English only for OS/system/security logs and operational messages.

## Visual Rules

- Preserve advanced effects and animations.
- Do not remove logos.
- Do not collapse the boot into plain text except as a bounded safety fallback.
- `Owl1.jpg` is a fixed bottom-left watermark/loading animation in WhekeOS stage.
- The matrix overlay is red, isolated to the right side, and must not overwrite the main boot frame.

## MCP / ASCII Motion

- ASCII Motion work is done through the Termux workspace and the Codex MCP server configuration in `~/.codex/config.toml`.
- A fresh Codex session may be required for new MCP tools to appear after config changes.

