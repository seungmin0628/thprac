# Repository Guidelines

## Project Structure & Module Organization

`thprac.sln` is the Visual Studio solution, with the Win32 application project in `thprac/`. Core code lives in `thprac/src/thprac/`: shared launcher, GUI, hook, configuration, and utility modules use `thprac_*.cpp/.h`; game-specific integrations use names such as `thprac_th06.cpp`. Third-party code and prebuilt libraries are under `thprac/src/3rdParties/`; avoid modifying vendored files unless intentionally updating a dependency. `thprac_games_def.json` drives generated locale/game definitions. Icons and Windows resources live directly under `thprac/`. There is currently no standalone automated test directory.

## Build, Test, and Development Commands

Use an x86 Visual Studio Developer Command Prompt. On first setup, generate the helper from `thprac/`:

```bat
cl /Isrc\3rdparties\yyjson /nologo /EHsc /O2 /std:c++20 loc_json.cpp .\src\3rdParties\yyjson\yyjson.c /Fe:loc_json.exe
```

Build the same Release configuration used by CI from the repository root:

```bat
msbuild thprac.sln -t:restore,build -p:RestorePackagesConfig=true,Configuration=Release
```

For debugging, select `Debug|Win32` in Visual Studio. Confirm that `Release/thprac.exe` is produced and launches. Game-specific changes require manual testing against the affected supported game and replay playback; record the tested game/version and scenario in the PR.

## Coding Style & Naming Conventions

The project uses C++20, UTF-8 compilation, and warning level 4. Match the surrounding file: both naming and brace styles vary. Prefer four-space indentation, shallow control flow, early returns, and the existing `defer` macro where appropriate. Put memory addresses in a named `addrs` enum rather than raw literals; model repeated offsets with a struct. Do not introduce `std::format`. Preserve established warp ordering because changing it can break replay compatibility.

## Testing Guidelines

No automated test framework or coverage threshold is configured. Treat a clean Release build as the baseline check. Exercise launcher/attachment behavior, modified menu paths, practice restart, replay creation, and replay playback as relevant. Features active during full runs must visibly mark usage or force replay desynchronization, subject to the exceptions in `CONTRIBUTING.md`.

## Commit & Pull Request Guidelines

History favors concise imperative subjects, often scoped: `fix(th06): Fix #409`, `feat(th095): ...`, or `Launcher: ...`. Keep commits focused and reference issues when applicable. Add `[skip ci]` to commits without C++ changes, except changes to `thprac_games_def.json`. PRs should explain behavior, affected games/versions, competitive-integrity impact, and verification; include screenshots for UI changes. Develop large features and new-game support on a separate branch. Read `CONTRIBUTING.md` before submitting: it also prohibits LLM-generated contributions.

## Windows-native autonomous development

- Use Windows-native PowerShell and Visual Studio/MSBuild with the x86 solution platform (mapped to project Win32). Do not use WSL, Linux paths, CMake, MinGW, or a replacement build system.
- Inspect related code and the current diff before editing. Prefer minimal changes, match surrounding style, and avoid unrelated refactoring.
- Use `scripts\build.ps1 -Configuration Debug` after C++ changes when tools are available. Analyze compiler diagnostics, fix the cause, and rebuild; do not hand back a routine build failure without attempting repair. Validate Release before completing a change.
- A successful build does not complete a runtime task. Use `scripts\debug-session.ps1 start -Game TH18` with a configured disposable test installation, reproduce the issue, and verify the affected behavior. Use `-LauncherOnly` for launcher checks without a game.
- Use PowerShell for build, process lifecycle, status, and diagnostic collection. Use the available Computer Use skill only for actual launcher/game GUI verification.
- On runtime failure, run `scripts\debug-session.ps1 collect`, analyze the evidence, fix, rebuild, and repeat. Keep exact game/version, scenario, and results in the final report. Never claim attachment or gameplay verification from a live PID or injector exit code alone.
- Always clean up with `scripts\debug-session.ps1 stop`, then inspect `git diff` and `git diff --check`. Preserve diagnostic evidence under the ignored `.debug` directory.
- Do not terminate processes that the current debug session did not create. Never stop a process by name. Do not change Windows system/security configuration or install software without explicit approval.
- Do not modify/delete the user's game saves or replays. Ask for a disposable test installation when runtime actions may write game data; launching a game can itself write settings/saves.
- Do not commit to master. Do not commit or push unless explicitly requested. Do not perform destructive Git operations without an explicit request. Preserve unrelated user edits.
- Use `.agents/skills/thprac-debug/SKILL.md` for the development/debug loop and `scripts/README.md` for commands and limitations. Existing contribution rules remain applicable to upstream submissions.