# defold-text-adventure — 『안개 속의 여섯 사람』

A click-driven Korean mystery text adventure built with Defold 1.13.1 as an experiment in agent-driven Defold development. Lua only, GUI only (no sprites, no physics, no image assets). Deduction game in the spirit of Return of the Obra Dinn / The Case of the Golden Idol: explore, collect clues into a notebook, fill in a five-slot report. Visual style: 1-bit ordered-dither illustrations painted procedurally at runtime (early-Macintosh adventure look).

## Editor HTTP API (primary build/verify channel)

The Defold editor must be running with this project open. It exposes a local HTTP server:

- Port: `cat .internal/editor.port`. Token: `cat .internal/editor.token`. Never paste the token into files, prompts, or logs.
- Discover endpoints from `http://localhost:$PORT/openapi.json` — do not hardcode routes beyond the ones below.
- Build & run: `curl -X POST http://localhost:$PORT/command/build` (relaunches the game window).
- Read console (build errors, runtime `print`): `curl http://localhost:$PORT/console` → JSON `{lines: [...]}`.
- Hot reload changed files into the running game: `curl -X POST http://localhost:$PORT/command/hot-reload`
- API reference: `curl http://localhost:$PORT/ref` (JSON), or https://defold.com/llms.txt (fetch only the section you need).
- `/eval` (runs Lua inside the editor, needs `Authorization: Bearer $TOKEN`) is privileged. Its one sanctioned use here is compile-checking story data without a Lua binary: `load(editor.get("/main/story.lua", "text"))`.

No Bob CLI or standalone `lua` is installed; the editor build is the only build path.

## Verification

- Build must return `{"success":true,"issues":[]}`.
- On startup in debug builds the engine validates the story graph and art keys and prints `STORY_OK <scenes> <clues>` (or `STORY_ERR ...`) and one `SCENE <id> <page> <pages>` line per render. Read these from `/console`; no `ERROR:SCRIPT` or `ART_ERR` lines allowed.
- To inspect one scene without clicking through, set `[adv] start = <scene id>` (or `@notebook`) in `game.project` and rebuild (debug builds only; unknown ids are ignored). `[adv] all_clues = 1` pre-fills every clue so notebook/clue screens can be checked. Restore `start =` (empty) and `all_clues = 0` before finishing.
- Real-mouse UI check: the game window belongs to the `dmengine` process (`pgrep -f dmengine`). `orca computer get-app-state --app pid:$PID --json` screenshots it; `orca computer click` cannot focus it, so click with `cliclick m:X,Y w:120 dd:X,Y w:120 du:X,Y` using screen coords = window origin (from `orca computer list-windows`) + window-local coords (window is 960x752 including the 32 px title bar; screenshots are 2x). A press and release inside the same frame is dropped by Defold, hence the delay. An inactive window can swallow the first click, so click a neutral header spot (e.g. local 300,55) before the real click.

## Architecture

- `game.project` bootstraps `/main/main.collection`: one game object with one `gui` component (`main/game.gui`). The `.gui` file declares only the font; every node is created in code.
- `main/game.gui_script` is the engine: state, scene navigation (`@back`, `@notebook`, `@restart`), pagination via `resource.get_text_metrics`, 1/2-column choice layout, hover/click picking, toasts, notebook, report (slots → option picker → submit), story validation. Display is 960x720; scenes with `art` draw an 840x168 banner under the header and start body text at `BODY_TOP_ART`; notebook/report screens have no banner.
- Notebook (`enter_notebook` / `render_notebook_page`) is a paged 2-column grid of clue titles (page size derived from the free height); `open_clue` shows one clue with an 840x240 banner keyed `clue:<id>` plus prev/next. Neither touches `scene_stack`, so `@back` returns to the scene that opened the notebook.
- `main/art_clues.lua` holds one drawing function per clue id (canvas 420x120, primitives via `art.P`). Every clue in `S.clues` must have one; validation prints `STORY_ERR clue without art` otherwise.
- `main/art.lua` paints every illustration: grayscale canvas (values 0 = ink, 1 = paper) → Bayer 8x8 dither → rgb bytes for `gui.new_texture` (rows top-first, no flip). `art.render(key, w, h)` is cached per key/size; `art.has(key)` validates. Keys are `<scene>` or `<scene>+<portrait>` (`S` table = scenes, `PORTRAITS` = han/jang/baek/seo/lim/doyun). 1-bit rule: solid ink shapes with light outlines, dither only for fog/gradients; keep every coordinate integer (`set` floors, but shape helpers expect integer anchors).
- `main/story.lua` is the only content file: `title`, `start`, `clues`, `notebook_choices`, `scenes`. Each scene may carry `art = "<key>"`; unknown keys fail validation. Scene `text` is a string or `function(state)`; paragraphs are separated by a blank line and the engine paginates them. Choice `cond`/`effect` and scene `on_enter` receive `state` (`state:add_clue`, `state:has`, `state:set`, `state:get`, `state.visited`). The `report` scene type holds the deduction slots with 1-based `answer` indexes. Never hardcode story text in the engine.
- Story rule: every clue in `S.clues` must be granted somewhere and every scene reachable; the /eval compile check plus `STORY_OK` cover this.

## Conventions & gotchas

- Defold resource files (`.collection`, `.gui`, `.font`) are protobuf text. Match field names exactly; copy from an editor-generated file when unsure.
- Font: `main/korean.font` bakes `assets/fonts/PretendardVariable.ttf` at 28 px as a bitmap with an explicit `characters` list (ASCII + KS X 1001 Hangul 2,350 + punctuation + ▶①-⑥■ etc.). Any new symbol used in UI or story must be appended to that list or it renders as a wrong glyph. Variable-font weights are not selectable; only Regular is baked. Do not enable `all_chars`.
- Only one font is declared; UI size differences come from `gui.set_scale`.
- `gui.get_text_metrics` does not exist in 1.13; use `resource.get_text_metrics(gui.get_font_resource("korean"), text, {width=, line_break=true, leading=})`.
- Lua arrays are 1-indexed. Compare `action_id` with `hash("touch")`, never strings.
- `.internal/`, `build/`, `.editor_settings` are editor-owned and gitignored; never edit or commit them.
- Before changing files outside `main/`, `assets/`, `input/`, or `game.project`, ask.
