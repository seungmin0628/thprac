# Environment validation (2026-09-13)

Validated on Windows-native PowerShell 7, Visual Studio Build Tools 2026 18.10, MSVC 14.51 (v145), and Windows SDK 10.0.26100.0. No software was installed and no Windows settings were changed.

| Check | Result | Evidence / limitation |
| --- | --- | --- |
| Repository inspection | PASS | README, solution, vcxproj, CI main.yml, generator, logging/config/init sources, AGENTS.md, CONTRIBUTING.md, existing skill and scripts inspected. |
| Release baseline | PASS | Actual compile/link; exit 0, 0 errors; existing vendored ImGui C4100 warning. .debug/build/Release-20260913-150636-990.log |
| Debug via automation | PASS | Actual Debug/x86 (project Win32) compile/link; exit 0, 0 errors. .debug/build/Debug-20260913-150729-779.log |
| Working directory independence | PASS | Debug invoked by absolute script path with C:\Users\smlee as working directory. |
| Output binaries and symbols | PASS | Debug and Release executable PE machine = 0x14c (x86); nonempty corresponding PDBs present. |
| Missing loc_json helper | PASS | Existing helper moved to .debug/loc_json-before-validation.exe; script rebuilt helper from source and completed Debug build (151317 log). |
| Incremental generation | PASS | Subsequent Debug build passed; helper and both generated locale files retained identical modification timestamps (151413 log). |
| Launcher start/status/collect/stop | PASS | Isolated Debug launcher started; native log and metadata collected; retained handle exit code recorded; stopped. |
| GUI verification | PASS | Computer Use observed the session's thprac - Touhou Game Launcher window, Games list, and successful Tools tab transition. No game-launch buttons used. GUI session ID: 27bc89e5b6b04f99835db9c092e6c819. |
| Repeated stop | PASS | Second stop returned successful stopped state with no extra process termination. |
| Missing game executable | PASS | start -Game TH18 -GamePath C:\nonexistent-thprac-test\th18.exe returned 1 with configuration instructions, before launching anything. |
| Invalid configuration | PASS | build -Configuration Invalid rejected by ValidateSet, exit 1. |
| PID reuse defense | PASS | A current process record with a mismatching creation time was rejected without terminating that process. |
| Concurrent state reads | PASS | 100 state reads during worker writes completed with valid running state. |
| Worker death/recovery | PASS | Only the session's worker was intentionally terminated; status reported stale, stop recovered the exact owned launcher, and both were confirmed absent. Session: de122dd7355043258a83cd7cd786c681. |
| JSON diagnostics | PASS | Final diagnostics parsed, including empty dump array; unavailable/no-match event collection noted explicitly. |
| PowerShell syntax | PASS | All tracked script candidates parsed without PowerShell syntax errors. |
| Windows PowerShell 5.1 execution | NOT TESTED | Direct powershell.exe -NoProfile -File invocations were blocked by that host's existing execution policy. PowerShell 7 invocations worked; policy was not bypassed or changed. |
| Skill structure | PASS | Required name/description frontmatter, matching directory/name, workflow, and reference paths inspected. Repository-local layout confirmed from official Codex documentation. |
| Bundled skill quick_validate.py | NOT TESTED | Attempted, but its import failed because PyYAML is absent. No dependency installed. |
| Real Touhou attachment/practice/replay | NOT TESTED | No test game environment variable/local path was provided. Requires a disposable supported game installation and version-specific scenario. |
| Actual crash/dump attribution | NOT TESTED | No crash forced; no native dump handler found. Collector inventories existing default WER paths and event candidates only. |
| Git whitespace / scope | PASS | git status, git diff and git diff --check checked; no C++/vcxproj/CI changes, no commit/push. |

Initial issues found and repaired through reruns: PowerShell null-string conversion in atomic replacement, a read/replace file-sharing race, hidden interactive window startup, explicit success exit code for composition, and empty-array JSON serialization. Failure evidence is retained in older ignored sessions.

Final runtime evidence remains under .debug/sessions. GUI-session diagnostics include 20260913-151232-490 (live) and 20260913-151256-943 (stopped). Worker-recovery diagnostics are in de122dd7355043258a83cd7cd786c681/diagnostics/20260913-151521-435. All processes belonging to validation sessions were checked after cleanup; none were left running.
## TH06 / thcrap integration (2026-09-13, follow-up)

The current local TH06 configuration uses the installed thcrap loader with config/ko.js and a disposable copy of the supplied Japanese-named executable. The original 348 TH06 files were hashed before copying and verified unchanged after both runtime sessions. No game installation, patch stack, or games.js was edited. Machine-specific paths are stored only in ignored debug.local.json; its game path intentionally remains the disposable copy.

| Check | Result | Evidence / limitation |
| --- | --- | --- |
| Debug / Release | PASS | Both automation builds returned 0, no errors. Logs: Debug-20260913-193932-800.log, Release-20260913-194541-049.log. |
| Real thcrap launch | PASS | Installed stable 2026-09-04 loader; ko.js patch stack; TH06 v1.02h; Japanese executable name. |
| Unicode path repair | PASS | Initial positional executable was treated as a games.js ID by the loader. Session-local thcrap-target.js with an exe field resolved it; existing patch configuration preserved. |
| Root bootstrap / TH6 alias | PASS | Root thcrap_loader.exe resolved to bin/thcrap_loader.exe; -Game TH6 normalized to TH06. |
| Owned game detection | PASS | Actual game selected by full path and private job membership after the loader exited normally. |
| Patch initialization / injection | PASS | Game had the installed bin/thcrap.dll loaded; thprac injector exited 0; the game created its own thprac_log.txt in the copy's portable data directory. This establishes initialization, not all practice behavior. |
| GUI rendering | PASS | Computer Use observed the Korean TH06 v1.02h title and active demo playback in the exact copied game window. |
| thprac menus / practice / replay | NOT TESTED | F12/Escape/Z/Return automation did not demonstrate a thprac menu or controlled practice scenario. Do not infer those results from injection or the rendered demo. |
| Normal stop | PASS | Session-owned game exited; state retained exit code and diagnostics. |
| Worker death | PASS | Intentionally terminating only the session worker closed its job; the real TH06 process exited within five seconds; stop recovery completed. |
| Ownership regression script | PASS | scripts/test-debug-job.ps1: Unicode/quotes/backslashes, early loader exit, surviving child lookup, job close, unrelated same-name process survival, stale PID rejection. |
| Missing patch config / no thcrap | PASS | Both rejected with exit 1 before session creation; original local config restored. |
| Diagnostics | PASS | Metadata includes loader PID/exit code and thcrap DLL; thcrap/native logs copied; target overlay copied and loader/config/target hashes recorded. |
| User data / cleanup / whitespace | PASS | Original TH06 file hashes unchanged; validation sessions cleaned up; script parse and git diff --check completed. |

Runtime evidence: .debug/sessions/02f3c924bcb547e1b96ac7b41fe060c4 (normal stop) and .debug/sessions/7254bb2332774c3388b9f171494c0ca4 (worker-death cleanup). The earlier failed Unicode-argument attempt remains in .debug/sessions/9284f7d2feaa43aaa14bb1c40d124cab.

Run `scripts\debug-session.ps1 start -Game TH06` from PowerShell 7 to reuse the configured test copy. For a different patch stack, change only thcrap.config in debug.local.json to an existing .js configuration. The worker uses a separate target overlay and leaves the patch stack untouched.

The final launcher regression exposed a transient state-file open conflict during atomic replacement. Read-DebugJson now retries bounded sharing failures; launcher-only start/stop and 200 concurrent reads passed after the fix. The ownership regression script also passed again.
