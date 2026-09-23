# Game keyboard verification

Use `game-input.ps1` for managed test-game keyboard input. The repository owner
explicitly authorized this helper as an exception to Computer Use-only input on
2026-09-22. Continue using Computer Use for screenshots, window selection and
mouse actions. Do not modify the installed Computer Use plugin.

## Why a dedicated input path

Computer Use exposes instantaneous `press_key`, but no hold duration or separate
key-down/key-up API. The initial TH06 v1.02h check did not demonstrate menu
control with that API. Timed scan-code input did. This establishes a working
alternative, not proof that timing alone caused every previous failure.
thprac's keyboard polling also requires foreground focus (`thprac_gui_input.cpp`).
TH06 automatically enters demo playback while an agent is examining the title
screen; stale menu observations can therefore produce misleading failures.

## Commands

Start a disposable configured game with `debug-session.ps1`. Read its returned
session ID and select its exact game window through Computer Use before input.
Use that literal ID throughout the scenario; do not silently switch to a new one.

```powershell
# Replace with the ID returned by the session you actually observed.
$testSessionId = '<32-character session ID>'
.\scripts\game-input.ps1 -SessionId $testSessionId -Keys Down
.\scripts\game-input.ps1 -SessionId $testSessionId -Keys Z
.\scripts\game-input.ps1 -SessionId $testSessionId -Keys Left,Shift,Z -HoldMs 600
.\scripts\game-input.ps1 -SessionId $testSessionId -Keys Escape
```

Default hold is 120 ms; accepted range is 30–2000 ms. Comma-separated keys are
held simultaneously. Separate calls are separate presses, with a released-key
interval. Supported keys are arrows, Z/X/C/A/S/D/V/R, Shift/Ctrl, Enter/Escape,
Backspace/Tab/Space and F1/F11/F12. F1 is thprac's invincibility toggle in
supported games and can keep the player alive while isolating a bomb test;
record its use as part of the test scenario. Add other game keys only with their documented
scan codes and an appropriate runtime check. Do not use text typing for gameplay.

The script shares the lifecycle lock, requires a running game (not launcher-only),
checks PID/path/creation time using a retained process handle, activates its main
window, checks foreground ownership before input and every 10 ms during a hold,
and releases the chord in `finally`. It rejects stale IDs and concurrent commands.
Successful sends are recorded in the session's `input.jsonl`; this records delivery,
not game acceptance. No DLL, game-memory write or system setting change is used.

Windows SendInput is global foreground input, not private process delivery. Avoid
using the keyboard/mouse concurrently. Focus loss aborts the hold and releases
keys; a focus race can still occur between checks. Do not forcibly terminate the
PowerShell input process while keys are held, since process termination cannot
guarantee `finally` runs. Holds are bounded to two seconds. If SendInput fails,
collect diagnostics; do not escalate privileges or alter security settings.

## Initial qualification and recovery

Perform the following control checks once while provisioning each game setup.
Subsequent development tasks should start their requested feature verification
directly, using the recorded setup. Repeat qualification only after changes to
the game installation, input or launch environment, or an observed failure.
Automatic process identity and foreground checks remain part of every input;
they require no separate user-facing readiness step.

1. Observe the real game/version, current menu and session identity. Confirm a
   disposable installation. The owner authorized ordinary non-replay game-data
   writes during this verification, so a separate save location is unnecessary.
2. Confirm one directional selection change and Z/Enter confirmation, then a
   cancel/back action. Let transition animations finish (TH06: about 700–1000 ms).
3. Enter a practice scenario. Verify all four directions, Z shooting, X bomb,
   Shift+direction slow movement, and movement+Z together. Compare equal hold
   durations away from screen edges; collisions/respawns invalidate comparisons.
4. Verify Escape pause/resume, thprac F12 options and practice restart. Pause
   before spending time reasoning, reading code or building. A short known
   resume → action → pause sequence can be issued in one PowerShell call, then
   inspect the screenshot. Do not queue an unobserved long playthrough.
5. If an action has no visible result, reobserve, check focus and whether the game
   is in a transition/demo/paused state. Retry a bounded hold once in a stable
   context; collect diagnostics if still ineffective. Do not keep sending the
   same instantaneous input or declare that a live PID proves gameplay.
6. Do not save a replay in this verification. Record anything not tested.
7. Collect and stop the session with `debug-session.ps1`; never kill by name.

## TH06 v1.02h / thcrap ko.js observations

On 2026-09-22, the configured disposable TH06 copy passed menu confirmation,
Up/Down selection, all four movement directions, combined movement/shooting,
slow movement, bomb (3 → 2), pause/resume, title return, F12 advanced options,
Practice Start configuration, and R restart from the thprac practice pause menu.
With a 600 ms hold, slow left moved approximately 114 screen pixels and normal
right approximately 216 pixels. Restart restored the initial player position and
stage opening. Exact pixels depend on window scaling and frame timing.

The title enters automatic demo playback in the time between agent observations.
When a demo is observed, Escape held for 1000 ms followed by a 700 ms transition
wait returned to the main menu. A short known sequence of Down, Down, Z then
entered Practice Start before demo timeout. Inspect the resulting difficulty
screen before continuing. Do not use this sequence blindly from a different state.
Choose difficulty → character → shot with separate Z presses and transition
observations. Practice Start opens thprac's setup; ordinary Start does not.
In custom practice, Escape opens the four-button thprac pause menu and R restarts.

Evidence: `.debug/sessions/6ce0a76527b24481ac9a332ad26acc89` (state, diagnostics,
input.jsonl), plus screenshots in the task. No replay save/playback, other games,
full-screen mode or alternate keyboard layouts were validated in this run.
Qualify each other target once; TH06 success is not a claim of universal support.

Additional checks passed: PowerShell parser, C# Add-Type compilation, x64 INPUT
structure size (40 bytes), rejection of stale session IDs, stopped sessions,
unsupported keys, holds above 2000 ms and concurrent lifecycle/input commands.
`scripts/build.ps1 -Configuration Release` passed with zero warnings/errors;
log: `.debug/build/Release-20260922-193849-170.log`. C++ sources were unchanged;
runtime checks used the existing Debug binary copied into the managed session.
Final collection: `diagnostics/20260922-193933-543` under the session above.
`debug-session.ps1 stop` completed and no session-owned processes remained.
Focus-loss and forced input-worker termination were not fault-injected.
