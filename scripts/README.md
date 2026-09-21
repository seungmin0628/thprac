# Windows development and debugging

Use ordinary PowerShell 7 with local scripts permitted by its existing execution policy. No Developer shell, PATH setup, WSL, or alternate build system is required. Scripts never change execution policy, install software, or configure Windows crash handling.

## Repository findings

README.md and .github/workflows/main.yml compile loc_json.cpp with MSVC, then use MSBuild restore + build for Release. The solution's platform is **x86**, mapped to **Win32** in thprac.vcxproj. Debug/Release use v145; LLVM variants are not selected by these scripts. Debug uses disabled optimization, /MTd, and compiler/linker PDBs. Outputs are Debug/thprac.exe and .pdb, or Release/thprac.exe and .pdb.

The project always invokes loc_json.exe before compilation. Its source compares generated content and only rewrites changed locale files; the scripts preserve that behavior. The helper is rebuilt when missing or older than its source/yyjson inputs. Existing build definitions and CI remain intact.

Logging is in thprac_log.cpp and configuration directory selection in thprac_cfg.cpp: executable-local .thprac_data takes precedence, otherwise AppData/thprac. Launcher and in-game logs rotate under logs. No native minidump/crash-handler implementation was found. There were no existing PowerShell build/session scripts; AGENTS.md and a thprac-development skill already existed and are preserved.

CONTRIBUTING.md prohibits LLM-generated contributions. This local workflow does not alter that upstream policy.

## Build

~~~powershell
.\scripts\build.ps1 -Configuration Debug
.\scripts\build.ps1 -Configuration Release
# Any working directory:
& 'C:\workspace\github.com\seungmin0628\thprac\scripts\build.ps1' -Configuration Debug
~~~

The scripts locate MSBuild using Visual Studio Installer's vswhere and initialize the matching x86 developer environment. Install prerequisites only with user authorization: Visual Studio C++ tools matching the project's v145 and a Windows SDK. A missing installation produces a diagnostic. Native build/helper exit codes are returned unchanged; script/setup failures return 1. Builds are serialized by an exclusive lock. Logs and MSBuild binary logs are in .debug/build.

Run build.ps1 as a script, not dot-sourced: it exits with the build result and initializes VS environment variables in its PowerShell process.

## Configure a game

Copy debug.example.json to **debug.local.json**, then replace example paths with absolute paths to disposable test installations. Alternatively set process environment variables:

~~~powershell
$env:THPRAC_TEST_TH18 = 'C:\Games\Touhou18-Test\th18.exe'
.\scripts\debug-session.ps1 start -Game TH18
~~~

Precedence: -GamePath, then THPRAC_TEST_<GAME>, then debug.local.json games entry. No secrets belong in these files. Real configuration and artifacts are ignored by Git. Scripts never edit/delete saves or replays, but the game itself may write data when launched or played. Use a disposable test installation with appropriately isolated saves; game-specific external save locations also need consideration.

### TH06 with thcrap (required for this workspace)

TH06 entries use the object form shown in debug.example.json: `path` is the actual game executable; `thcrap.loader` is the installed loader, `thcrap.config` is the existing patch-stack `.js` file, and `thcrap.workingDirectory` is the thcrap root. `timeoutSeconds` defaults to 60 (1–180). Other games can use the same object form or keep their original string paths. `TH6` is normalized to `TH06`.

~~~powershell
.\scripts\debug-session.ps1 start -Game TH06
~~~

An explicit -GamePath or environment path overrides only the game executable; it preserves the configured thcrap settings. TH06 without thcrap configuration is rejected before launch. The example contains placeholder paths; machine paths belong only in debug.local.json.

If a root thcrap_loader.exe is configured and bin/thcrap_loader.exe exists, the script uses the latter directly, avoiding the runtime-installing bootstrap. A missing loader/config is an error; nothing is installed. The installed loader may perform its normal patch update checks or show its own UI.

The worker passes the selected patch stack followed by a session-local thcrap-target.js containing the exact `exe` path. The loader merges these run configurations. This avoids an observed ANSI extension-detection problem with the Japanese TH06 executable name on this machine. Existing games.js and patch configuration files are not edited. See [the loader implementation](https://github.com/thpatch/thcrap/blob/master/thcrap_loader/src/loader.cpp) for configuration merging and the `exe` field.

DebugJob.cs is a small Windows API adapter loaded by PowerShell Add-Type, not a replacement build system. It creates the loader suspended, assigns it to a private Windows Job Object, then resumes it. The worker selects a game only when its full executable path matches and its retained process handle belongs to that job. It waits for GUI initialization and checks the loaded thcrap DLL before attaching thprac. Root/child handoffs remain tracked even when the loader exits first. Steam launchers that hand off to an already-running external process are not supported.

Job close kills only this launch's members, including on worker death or startup failure. thprac itself retains the existing identity-checked cleanup. No system-wide process-name search is used for attachment or termination. Do not launch additional games or external applications from within a managed game session.

Run `scripts\test-debug-job.ps1` for the no-game regression check: Unicode/quoted argument handling, early loader exit, child membership, cleanup, unrelated same-name process survival, and stale PID rejection. Fixtures and outputs remain under .debug.

## Session lifecycle

~~~powershell
.\scripts\debug-session.ps1 start -LauncherOnly
.\scripts\debug-session.ps1 status
.\scripts\debug-session.ps1 collect
.\scripts\debug-session.ps1 stop

.\scripts\debug-session.ps1 start -Game TH18
# Optional explicit path:
.\scripts\debug-session.ps1 start -Game TH19 -GamePath 'C:\Games\Touhou19-Test\th19.exe'
.\scripts\collect-debug.ps1
~~~

Start does not build implicitly. It copies the selected executable/PDB into an isolated session and supplies portable launcher settings disabling automatic game search. A hidden PowerShell worker starts the game directly or through the configured thcrap loader, then runs thprac --attach with the owned game PID. Interactive app windows are visible for verification. Do not launch more processes from the thprac GUI during a managed session.

A successful start means process launch, not successful injection or gameplay. An injector often exits normally while the game continues; the worker keeps monitoring the game. Use Computer Use for actual launcher/menu/practice verification and record the supported game version and scenario. Do not infer success from a PID or exit code.

.debug/session.json points to the current session by ID; .debug/sessions/<id>/state.json stores timestamps, target, paths, worker/thprac/game/loader PIDs and exit codes, thcrap configuration, and the observed DLL path. Old sessions and binary/PDB snapshots remain for analysis. One active session is supported. Commands are serialized and JSON state is atomically replaced.

Stop requests cleanup from the worker, which terminates its retained handles and closes its private thcrap job. It is idempotent. If the worker died, remaining handle recovery requires PID, exact creation time, and executable path to match before terminating. Unknown exit codes remain null. If state is corrupt, inspect it rather than deleting evidence or killing processes by name.

## Diagnostics and limits

Collect writes a dated diagnostics directory inside the session, containing metadata, live process snapshots, available exit codes, session worker output, recently modified native thprac/thcrap logs, executable/PDB/generated-locale hashes, relevant Application events (1000/1001/1002), and existing default WER dump paths.

Log/event collection is best-effort and records unavailable sources in collection-notes.txt. Shared native log directories and time/name-filtered events are candidates, not guaranteed attribution. No save/replay data is copied. No crash is forced, dump setting changed, or debugger installed. Custom WER dump locations are not searched. Keep local logs/binary logs private unless explicitly choosing to share them.

The worker persists across commands; always stop it after verification. External worker termination can lose exit codes. Session files are trusted local operational state, not a security boundary against a local user editing them.

## Codex workflow

The reusable skill is .agents/skills/thprac-debug/SKILL.md, in the repository directory supported by [official Codex skill documentation](https://learn.chatgpt.com/docs/build-skills). It defines baseline → inspect → minimal change → Debug build → reproduce → diagnose → fix → repeat → cleanup → Release/diff checks. Ask Codex to use thprac-debug explicitly if automatic discovery has not refreshed.

See validation.md for checks performed while establishing this environment.
