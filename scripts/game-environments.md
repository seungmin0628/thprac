# Game verification environments (2026-09-23)

The installation-path source is `F:/touhou/thcrap/config/games.js`.
`provision-game-env.ps1` creates ignored disposable copies in `.debug/test-games`,
omitting local score and replay files, and writes ignored `debug.local.json`.
Its `path` field is the copied configured launcher, and `gameExe` is the owned
child process to which thprac attaches. A private Windows job tracks handoffs.
The original installations are not changed by provisioning.

The owner explicitly accepted normal non-replay game-data writes on 2026-09-23
and said separate save-path isolation is unnecessary. Do not save a replay.
The worker still sets a per-session `APPDATA` environment variable where
configured, but Windows Known Folder APIs may resolve the original Roaming
AppData path; do not describe that variable as full save isolation.

| Game | Runtime result and remaining limitation |
| --- | --- |
| TH06 | v1.02h with thcrap `ko.js`: prior disposable copy passed Practice Start, pause, restart, directions, shot, slow movement and bomb. Current copy has the same game EXE SHA-256. |
| TH07 | v1.00b: `vpatch.exe` launch; Practice Start, pause, `R` restart, left movement and bomb (3 → 2) observed. Sessions `19c9c65bc3114804b51058f6f90e7e1b`, `a23409271cdd4f0da6908dd38fd1485c`. |
| TH08 | v1.00d: `vpatch.exe` launch; Practice Start, pause, `R` restart, left movement and spell use observed. Session `3e4f8af0502b4f0aadfdcc5a2b8dd783`. |
| TH09 | v1.50a launched from copied `vpatch.exe`; a signed-in Steam window covered the game, so practice controls were not observed. A Shift+Tab attempt was rejected by automatic approval review because the target window was uncertain. Session `6aeea0e92b404352a85cbdb91f18d3ee`. |
| TH095 | v1.02a: Game Start → Scene 1, left movement, Escape pause and the pause menu's Retry This Mission observed (timer 42.46, photos 0/3 after retry). No separate Practice Start or bomb mechanic; camera is the action. At an earlier failure screen, confirmation was rejected by automatic approval review because a Save Replay option was present and selection was uncertain. Sessions `f0d7b3655e8144c0b72d7a37bdab90b9`, `cc0bbfc4c96d4c7fa6f2231994aa24f2`. |
| TH10 | v1.00a: `vpatch.exe` launch; Practice Start, pause, `R` restart, left movement and bomb (power 5.00 → 4.00) observed. Session `633de85e78e0435f82f04b7af0770ddd`. |
| TH11 | v1.00a: `vpatch.exe` launch; Practice Start, pause, `R` restart, left movement and bomb (power 1.15 → 0.00) observed. Session `e8304cb3492c407f8a922e2794ee2796`. |
| TH12 | v1.00b: `vpatch.exe` launch; Practice Start, pause, `R` restart, left movement and bomb (spell count fell) observed. Session `2c6661809f56486b93014fdef61915c1`. |
| TH125 | v1.00a: photo-game Shooting Start → Scene 1, left movement, pause and `R` restart observed. No separate Practice Start or bomb mechanic; camera action was used to clear the tutorial. Session `ab54f8108d474dbeb483057615777d35`. |
| TH128 | v1.00a: Start → Route A1 → thprac Practice Mode → stage, pause and `R` restart observed. A second normal-mode run delivered Left and `X`; the game-over screen displayed Perfect Freeze 75%, but rapid defeat prevented isolating either action's effect. Sessions `2d9f2a5909ca4c1bbd421bcc70e125b6`, `dc57e8e692644fd28dd2c61f52f52596`. This game has an ice action instead of an ordinary bomb. |
| TH13 | v1.00c: Practice Start, left movement (x338 → x134), pause and `R` restart observed. `X` was sent, but bomb use could not be separated from repeated hits. An F1 invincibility-hotkey attempt did not establish a stable no-hit state. Sessions `edf697fc12e2402caf6debf6376528b3`, `ff6f282bf49b4ca7a84f581bb9baf7b7`. |
| TH14 | v1.00b: Practice Start, left movement (x338 → x130), pause and `R` restart observed. `X` was sent in both sessions, but repeated hits reset the spell count before observation, so bomb use remains unconfirmed. Sessions `4c3c1733384243f181c756fba61cc8a8`, `c47628ffd53f4240936bca6fdcf04ef5`. |
| TH143 | v1.00a: Game Start → first mission, Retry and Escape pause observed. No separate Practice Start or ordinary bomb. `R` returned from pause to gameplay, but did not restart the mission. The tutorial overlay and rapid failure prevented clear left-movement and item-action confirmation. Sessions `1c054c993c5340feb6eb66338b5eaa36`, `08816a674f074048970fb0a1c20f16ef`. |
| TH15 | v1.00b: `vpatch.exe` launch; Practice Start, left movement (x338 → x130), pause, `R` restart (score reset), and bomb (spell indicator eight → seven immediately after restart) observed. Session `044f02c8e0df48238e5b9e2dd009fdf1`. |
| TH165 | v1.00a: Game Start → first dream, left movement (x480 → x280), Escape pause and pause-menu Retry Dream observed; retry returned to the active dream with the timer at 77. No separate Practice Start or ordinary bomb. Sessions `5e5eb54e49834e3f98f65cdb06918953`, `a0e71ca18c064b39b4ab0f9cc2ef49da`. |
| TH17 | v1.00b: Practice Start, left movement (x338 → x130) and pause observed. `R` did not restart from the pause menu; the restart-menu navigation was rejected by automatic approval review because it passed a Save Replay entry. `X` was sent, but hits prevented an isolated bomb confirmation. Session `2e2477b3710c495ebd07e1965c947c24`. |
| ALCOSTG | v1.00a: `vpatch.exe` launch; thprac Practice Mode → stage, Escape pause and `R` restart (clock reset from 19:16 to 17:06, beer restored to 3.0 L) observed. The in-game clock advanced rapidly, and left movement or an `X` action could not be established before stage end. Sessions `4cb70c528a244aa3bacc58c14f5cb24d`, `3de45a5b38544d49b7966d33ce6bd26c`. No ordinary bomb counter is shown. |
| TH16, TH18, TH185, TH19, TH20 | The exact executable path specified in `games.js` is absent. No test copy or runtime verification is possible from that mapping. |
| TH06NC | No entry in `games.js`; Steam New Classic has a separate launch requirement. |

Every listed runtime session was collected and stopped. Inputs came from the
session-bound `game-input.ps1`; GUI claims above were checked with Computer Use
screenshots. Input delivery alone is not evidence that a game accepted a key.
The work requested in this session does not include saving replays.

`TH155` is absent from its configured path, and `TH175` is present, but neither
has a thprac practice initializer. `TH075`, `TH105`, `TH123`, `TH135` and `TH145`
are launcher-recognized without practice initializers and have no mapped
`games.js` entry. TH09 v1.00a is recognized without a practice initializer.
The source lists 23 distinct practice-supported game IDs, including TH06NC.
