---
name: thprac-debug
description: Implement and debug thprac changes on Windows with MSBuild, managed test sessions, runtime verification, and diagnostic-driven repair. Use for thprac feature implementation, bug reproduction, and launcher or game integration verification.
---

# thprac debug loop

Read the repository's AGENTS.md and scripts/README.md first. Resolve the repository root from this skill's location (three parents above this directory) when the shell is elsewhere. Preserve existing user changes and contribution policy.

1. Establish the baseline: inspect git status/diff, available VS C++ tools, current session status, configured test executable, supported game version, and the requested reproduction scenario. Run a Release baseline if its health is unknown.
2. Investigate relevant launcher, hook, game, and configuration code. Identify memory addresses from evidence; do not invent offsets.
3. Implement the smallest change that addresses the actual cause and follows nearby style.
4. Run `scripts\build.ps1 -Configuration Debug` using Windows-native PowerShell. Solution x86 maps to project Win32.
5. If compilation fails, read compiler output and .debug/build logs, repair the cause, and build again. Do not stop at a routine compiler, generator, path, or script error.
6. Start `scripts\debug-session.ps1 start -Game TH18` (substitute the configured target), or `start -LauncherOnly` for launcher work. The supplied game installation must be disposable if launching/playing can write saves or settings. An absent executable is an external limitation; do not search unrelated personal directories or substitute a different game.
7. Reproduce the original scenario. Check attachment in the actual game; a live PID or injector exit code zero is insufficient.
8. When GUI interaction is necessary, load the available Windows Computer Use skill, select the exact returned session window, observe, act, and reobserve. Build, start/stop, and collection remain PowerShell operations.
9. On failure, run `scripts\debug-session.ps1 collect`. Read process state, exit codes, launcher/in-game logs, matching event candidates, and existing dump inventory.
10. Analyze the root cause using evidence. Distinguish a normal injector exit from game failure and missing diagnostics from success.
11. Make a focused fix.
12. Stop the previous session, rebuild, start a fresh session, and repeat reproduction/verification until the requested behavior is demonstrated or a concrete external blocker remains. Verify relevant practice restart and replay behavior when safe and authorized; preserve existing replay compatibility and competitive-integrity rules.
13. Collect final diagnostics and always stop session-owned processes, including on failure. If the worker died, use the stop command's identity-checked recovery. Never terminate by process name or kill unrelated descendants.
14. Run the Release check, git diff, and git diff --check. Do not commit/push without an explicit request and never commit directly to master.
15. Report changed behavior/files, exact commands and PASS/FAIL/NOT TESTED results, game/version/scenario, diagnostic paths, cleanup status, and remaining limitations.

Continue analyzing, fixing, and rerunning for errors within the authorized local task. Report genuine blockers: absent game paths, required software installation, admin/system/security changes, or possible user data loss. Do not change security configuration or install software implicitly. Build success alone never proves a runtime task complete.