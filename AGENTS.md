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
- Real-mouse UI check: the game window belongs to the `dmengine` process (`pgrep -f dmengine`). `orca computer get-app-state --app pid:$PID --json` screenshots it; `orca computer click` cannot focus it, so click with `cliclick m:X,Y w:120 dd:X,Y w:120 du:X,Y` using screen coords = window origin (from `orca computer list-windows`, re-query it — macOS may shrink the 720x1560 window to fit the screen, e.g. down to 720x950 including the 32 px title bar; screenshots are 2x that) + window-local coords converted from the design (720x1560, bottom-left origin) by the same uniform FIT scale the GUI itself uses. A press and release inside the same frame is dropped by Defold, hence the delay. An inactive window can swallow the first click, so click a neutral header spot (e.g. local 300,55) before the real click. The window can also intermittently report "no on-screen window" between calls; retry with `--restore-window` and re-fetch its bounds rather than reusing stale coordinates.

## Architecture

- `game.project` bootstraps `/main/main.collection`: one game object with one `gui` component (`main/game.gui`). The `.gui` file declares only the font; every node is created in code.
- `main/game.gui_script` is the engine: state, scene navigation (`@back`, `@notebook`, `@restart`), pagination via `resource.get_text_metrics`, single-column choice layout (a few explicit two-up rows for prev/next nav), hover/click picking, toasts, notebook, report (slots → option picker → submit), story validation, unread-clue tracking. Display is 720x1560 portrait; every node sets `gui.ADJUST_FIT` so the design scales uniformly on other window sizes. Scenes with `art` draw a 720x144 banner under the header (rendered via `art.render(key, 840, 168)` — the texture stays full-size, only the display box shrinks) and start body text at `BODY_TOP_ART`; notebook/report screens have no banner.
- Notebook (`enter_notebook` / `render_notebook_page`) is a paged single-column list of clue titles (page size derived from the free height; the longest title doesn't fit two-up at this width); `open_clue` shows one clue with a 720x206 banner (texture `art.render(key, 840, 240)`) keyed `clue:<id>` plus prev/next. Neither touches `scene_stack`, so `@back` returns to the scene that opened the notebook. `state.unread` (set by `state:add_clue`, cleared by `open_clue`) drives two indicators: unread clue titles render with the `korean_sb` font in the notebook grid, and the header's notebook button pulses alpha 1.0↔0.45 (`start_blink`, a chained one-shot `gui.animate` + `timer.delay` loop, not `gui.PLAYBACK_LOOP_PINGPONG` — see gotchas) while `state:unread_count() > 0`.
- `main/art_clues.lua` holds one drawing function per clue id (canvas 420x120, primitives via `art.P`). Every clue in `S.clues` must have one; validation prints `STORY_ERR clue without art` otherwise.
- `main/art.lua` paints every illustration: grayscale canvas (values 0 = ink, 1 = paper) → Bayer 8x8 dither → rgb bytes for `gui.new_texture` (rows top-first, no flip). `art.render(key, w, h)` is cached per key/size; `art.has(key)` validates. Keys are `<scene>` or `<scene>+<portrait>` (`S` table = scenes, `PORTRAITS` = han/jang/baek/seo/lim/doyun). 1-bit rule: solid ink shapes with light outlines, dither only for fog/gradients; keep every coordinate integer (`set` floors, but shape helpers expect integer anchors).
- `main/story.lua` is the only content file: `title`, `start`, `clues`, `notebook_choices`, `scenes`. Each scene may carry `art = "<key>"`; unknown keys fail validation. Scene `text` is a string or `function(state)`; paragraphs are separated by a blank line and the engine paginates them. Choice `cond`/`effect` and scene `on_enter` receive `state` (`state:add_clue`, `state:has`, `state:set`, `state:get`, `state.visited`). A choice that means "go back" (return to a hub, end a conversation, cancel) should carry `back = true`; the engine also auto-detects `next = "@back"`. Either renders the button as a lower-emphasis "ghost" style — same size/position, just no fill and a dimmer border/label. The `report` scene type holds the deduction slots with 1-based `answer` indexes. Never hardcode story text in the engine.
- Story rule: every clue in `S.clues` must be granted somewhere and every scene reachable; the /eval compile check plus `STORY_OK` cover this.

## Conventions & gotchas

- Defold resource files (`.collection`, `.gui`, `.font`) are protobuf text. Match field names exactly; copy from an editor-generated file when unsure.
- Fonts: `main/korean.font` bakes `assets/fonts/PretendardVariable.ttf` at 36 px, `main/korean_sb.font` bakes `assets/fonts/Pretendard-SemiBold.ttf` at the same 36 px — both with an identical explicit `characters` list (ASCII + KS X 1001 Hangul 2,350 + punctuation + ▶①-⑥■ etc.). Any new symbol used in UI or story must be appended to *both* lists or it renders as a wrong glyph. Do not enable `all_chars`.
- Both fonts are declared in `main/game.gui` (names `korean`, `korean_sb`); UI size differences come from `gui.set_scale`, weight differences from picking the font name in `create_text`/`create_button`.
- Toasts are drawn as free-floating nodes outside `self.nodes` (so `clear_screen` doesn't delete a fading toast mid-transition) — but that also means draw order matters: `drain_toasts` must run *after* the new screen's nodes are built (`enter_scene` calls it last), otherwise the toast is created first and the new scene's body text/art paint over it, making it invisible. Don't move `drain_toasts` back before a render call.
- `gui.animate(..., gui.PLAYBACK_LOOP_PINGPONG)` on a `color`/`color.w` property could not be visually confirmed to progress during automated screenshot testing (the header notebook-button blink) even though the same call pattern on `position.x` and a one-shot `color.w` fade both worked — possibly because the engine only advances animation state while the window is genuinely focused, which this environment's screenshot tooling can't sustain continuously. The blink is implemented instead as `start_blink`: chained one-shot `gui.animate` calls driven by `timer.delay`, gated by a `self.blink_token` that `clear_screen` invalidates. Prefer that pattern over `PLAYBACK_LOOP_PINGPONG` for anything that needs to be screenshot-verified here.
- `gui.get_text_metrics` does not exist in 1.13; use `resource.get_text_metrics(gui.get_font_resource("korean"), text, {width=, line_break=true, leading=})`.
- Lua arrays are 1-indexed. Compare `action_id` with `hash("touch")`, never strings.
- `.internal/`, `build/`, `.editor_settings` are editor-owned and gitignored; never edit or commit them.
- Before changing files outside `main/`, `assets/`, `input/`, or `game.project`, ask.
