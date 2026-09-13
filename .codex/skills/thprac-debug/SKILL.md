---
name: thprac-debug
description: Build and debug this thprac repository from WSL2 using Windows Visual Studio/MSBuild, named thprac/Touhou test sessions, GUI verification, and collected diagnostics. Use for thprac implementation, build failures, launcher or injection issues, and game-specific runtime verification in this repository.
---

# thprac Debug Loop

Work from the repository root. Use Windows PowerShell for the supplied scripts; do not substitute the WSL compiler for this Win32 Visual Studio project.

## Loop

1. Read `AGENTS.md`, inspect the affected code, and define the smallest observable verification for the change.
2. Build Debug from WSL:

   ```sh
   powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$(wslpath -w scripts/build-debug.ps1)"
   ```

   On failure, inspect `.codex/debug/build/latest.json`, its `consoleLog`, and its `binaryLog`. Diagnose the first causal compiler/linker error before editing.
3. For repeatable local paths, copy `.codex/thprac-debug/config.example.json` to the ignored `config.json`, edit it, and validate aliases with `debug-session.ps1 games`. Start a named session using the affected game alias:

   ```sh
   powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$(wslpath -w scripts/debug-session.ps1)" start -Name th06-smoke -Game th06
   ```

   The config's `defaultGame` is used when no game is specified. Use `-LauncherOnly` for a launcher-only check, `-GamePath` for a one-off path, or `-ConfigPath` for an alternate config. Explicit CLI paths take precedence over config values.

   For games that must start through thcrap or another wrapper, set `launchMode` to `externalAttach`, keep `path` and `arguments` pointed at the wrapper, and set `processPath` to the actual game executable. Add `requiredModules` such as `thcrap.dll` when the session must prove that the integration loaded. List wrapper-owned helpers such as `vpatch` in `companionProcessNames` so named stop and failed-start cleanup include them. The script launches the wrapper, waits for the exact game process, verifies the required modules, then invokes thprac with `--attach <pid>`.
4. Confirm the session with `debug-session.ps1 status -Name <name>`. For an external-attach session, require the game entry to report `integration=True`; a running wrapper alone is not success. Verify the requested behavior. When the Computer Use capability is available, inspect and operate the returned thprac/Touhou window directly; never use it to automate a terminal. Record the game, version, screen or menu path, and observed result.
5. Collect evidence before stopping a failed or crashed session:

   ```sh
   powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$(wslpath -w scripts/collect-debug.ps1)" -Name th06-smoke
   ```

   Inspect the bundle's `status.json`, `processes.json`, stdout/stderr logs, `application-events.json`, dumps, and copied build logs. Separate a thprac failure from a game, injection, antivirus, or environment failure.
6. Stop only that session with `debug-session.ps1 stop -Name <name>`, make the smallest justified fix, then repeat build and the same scenario.

## Boundaries

- Do not stop unrelated thprac or Touhou processes; use only the named session script.
- Do not claim runtime verification when no relevant game executable is available. Report launcher-only verification explicitly.
- Preserve CI's Release behavior. `scripts/build.ps1` builds `loc_json.exe` first because the project consumes but does not produce it.
- After three iterations with the same causal failure, stop editing, collect a fresh bundle, and report the evidence and required user/environment action.
- Finish with the exact build command, session name, game/version if any, observed GUI behavior, diagnostic bundle path, and remaining uncertainty.
