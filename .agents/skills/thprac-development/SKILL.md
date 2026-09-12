# thprac development

Use this skill when working on touhouworldcup/thprac or its forks.

## Repository workflow

- Treat touhouworldcup/thprac as upstream.
- Keep personal changes isolated into focused commits.
- Before preparing an upstream PR, identify the minimal cherry-pickable commit set.
- Avoid unrelated refactors in upstream-bound changes.

## Investigation

- Search existing game implementations before introducing new patterns.
- Prefer existing abstractions and conventions used by adjacent Touhou titles.
- For game-specific memory addresses or patches, identify the supported executable/version before modifying code.
- Do not infer memory offsets without evidence from the repository or verified reverse-engineering results.

## Build and verification

- Follow the repository's MSVC/MSBuild build procedure.
- Verify compilation before considering an implementation complete.
- For behavior that cannot be automatically tested, state the exact in-game validation procedure.

## Sources

- Prefer official documentation, upstream source code, and original reverse-engineering evidence.
- Cite the original URL when using external information.
