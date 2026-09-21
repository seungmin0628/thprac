# New Classic support in thprac

The existing `thprac.exe` includes the Steam New Classic adapter from
[zxxsmart/thprac-th06nc v1.1.0](https://github.com/zxxsmart/thprac-th06nc/tree/v1.1.0).
Its original MIT license and third-party notices are preserved in
`THIRD_PARTY_NC_NOTICES.txt`. This is a local integration, not an official upstream release.

Run `thprac.exe`, select **TH06NC**, enable **Apply thprac**, and select **Start game**.
In the game select **Practice Start**, difficulty, character, stage, then the practice
settings and Z. Steam must be installed and the game owned and installed separately.
The existing Tools menu can also attach to a running supported New Classic process.

Supported: Steam th06nc **1.03**, Windows x64, executable SHA-256
`07850c8c6e469c0e82c13423e6d0d096a88d693455bdacacbb44c0aa3bcce473`.
The bridge verifies the complete executable hash before injection.
Game updates require a corresponding adapter update.

Only `thprac.exe` needs to be distributed. It embeds the x64 bridge, game module,
FreeType dependency and licenses. On first use it extracts them into
`%LOCALAPPDATA%\thprac\th06nc\<bundle-hash>`, verifying their contents before use.
It does not install DLLs into the game folder. x64 build outputs are intermediate
files under `x64/Debug` or `x64/Release`.

Build with `scripts/build.ps1 -Configuration Debug` or `-Configuration Release`.
The existing x86/Win32 solution builds both x64 MSBuild projects and embeds their
outputs as resources. Visual Studio v145 x86/x64 tools and Windows SDK are required;
no CMake, Python or Clang installation is needed.

Rebuild this integration to update it. The upstream binary auto-updater is disabled
for executables with the NC bundle, because it would replace the integrated build
with a release that does not support New Classic. Existing update preferences are
preserved in settings.

The adapter preserves the fork's practice controls, replay metadata v7 and optional
low-latency mode (off by default). Keep both `.rpy` and `.rpy.thprac-nc` replay files.
Practice modifiers are visibly indicated; do not assume this unofficial adapter is
approved for competitive play. Existing original TH06 warp ordering is unchanged.

Prefer a disposable game installation for runtime tests. Testing an existing
installation requires the owner's explicit authorization because the game may
write settings or saves. Launcher validation alone does not verify injection,
practice restart or replay playback.
