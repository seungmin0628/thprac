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
