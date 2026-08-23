# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

This is **Gotik**, a Godot 4.7 project (Forward+ renderer, Jolt Physics for 3D, D3D12 rendering
device on Windows — see `project.godot`). The project is currently an empty scaffold: there is no
game code, no scenes, and no scripts of its own yet. The only content besides engine config is the
`addons/godot_mcp` editor plugin (see below). When adding the first game systems, there is no
existing convention to match — pick a standard Godot layout (e.g. `scenes/`, `scripts/`,
`assets/`) and stay consistent once one is chosen.

There is no package manager, build system, linter, or test runner in this repo — it's a pure Godot
project, driven entirely through the Godot editor/CLI.

## Running the project

Use the Godot 4.7 editor (GUI or CLI):
- Open the editor: `godot --path .`
- Run the project headless/CLI: `godot --path . --headless` (add scene args as needed)
- There is no separate build step; Godot compiles/imports assets on open.

**Never hand-edit `project.godot` directly** — the Godot editor rewrites it constantly, and any
manual edits are liable to be silently clobbered. If a project setting needs to change and the
`godot_mcp` addon is active, use its `set_project_setting` MCP tool instead; otherwise change it
through the editor's Project Settings UI.

## The `godot_mcp` addon

`addons/godot_mcp/` is "Godot MCP Pro" — an `EditorPlugin` that runs *inside* the Godot editor and
exposes editor/runtime automation over a local WebSocket server (ports 6505–6514), so an AI
assistant (e.g. Claude Code via an MCP client) can drive the editor: create scenes/nodes, write and
attach scripts, playtest, simulate input, inspect the running game, etc. Treat this as
infrastructure/tooling, not gameplay code.

Architecture:
- `plugin.gd` — `EditorPlugin` entry point. On `_enter_tree`, it wires up the command router and
  WebSocket server, injects three autoload singletons (`MCPScreenshot`, `MCPInputService`,
  `MCPGameInspector`) needed for runtime introspection, and adds a status panel to the bottom
  editor dock. It cleans all of this up again in `_exit_tree`, including autoloads it injected and
  temp IPC files — it's careful not to touch autoloads the project itself owns.
- `websocket_server.gd` — the transport; hands incoming requests to `command_router.gd`.
- `command_router.gd` — registers every file in `commands/` as a command module. Each module
  extends `base_command.gd` and returns a `{method_name: Callable}` map from `get_commands()`;
  the router flattens all of these into one dispatch table (~25 modules, one per domain: scenes,
  nodes, scripts, animation, tilemap, physics, audio, shaders, export, Android, etc.).
- `commands/base_command.gd` — shared base class for all command modules. Notable shared
  machinery here: `success()`/`error()` result-envelope helpers with JSON-RPC-style error codes,
  `*_with_undo` helpers that route node/property changes through Godot's `EditorUndoRedoManager`
  (so AI-driven edits stay Ctrl+Z-able), guards that refuse to overwrite a scene/script/resource
  that's currently open and unsaved in the editor, and `send_game_command()` — a file-based IPC
  channel (`user://mcp_game_request` / `mcp_game_response`) used to talk to the *running game
  process* from the editor process, since they're separate processes and only one game command can
  be in flight at a time.
- `ui/status_panel.gd` — bottom-dock panel showing server/connection status.
- `mcp_screenshot_service.gd`, `mcp_input_service.gd`, `mcp_game_inspector_service.gd` — the
  autoload singletons injected into the *running game*, used for screenshots, simulated input, and
  live scene/property inspection during playtesting.

Full tool catalog and usage patterns (scene/script workflows, animation, playtesting loop, common
pitfalls) are documented in `addons/godot_mcp/skills.md`.

### Conventions the addon itself enforces (relevant if editing addon code or driving it via MCP)

- Prefer setting visual properties (position, color, theme overrides, etc.) via node properties/the
  inspector over hardcoding them in GDScript, so values stay visible and tweakable.
- GDScript `for` loops over untyped `Array`/`Dictionary` values need explicit type annotations on
  the loop variable — type inference fails otherwise.
- After creating/modifying scripts through the addon, the project needs a reload for the editor to
  pick up changes.
