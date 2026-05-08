# MSHV macOS Port

This file was renamed from the original `mhsv-osx` repo's `readme.md` when the macOS port worktree was moved onto the GitHub fork.

This repo tracks a macOS port of MSHV while keeping the code as close to upstream as practical.

Upstream references:

- Project page: <https://lz2hv.org/node/10>
- Source releases: <https://sourceforge.net/projects/mshv/files/>

As of 2026-05-03, the latest upstream full source archive visible from the project page is `MSHV_2765_Full_Source_Code.zip`, published on 2026-03-24.

## Goal

Port MSHV to macOS with the smallest practical patch set:

- keep decoder and protocol logic unchanged
- keep the Qt and `qmake` build layout unless forced to change
- isolate macOS code behind narrow platform-specific changes
- avoid new third-party dependencies unless a platform replacement is unavoidable

## Current Repo Status

As of 2026-05-07, the repo is past the initial port-planning stage and has a working macOS build path plus several runtime fixes, packaging updates, and recent multi-answer changes.

Historical baseline notes:

- the macOS port work started from the SourceForge `MSHV_2765` source archive
- the old staging repo carried the early source audit and baseline capture before the port was rebased onto the GitHub fork
- the current fork worktree is based on upstream GitHub `MSHV v.2.76.6`

The upstream tree as extracted contains 575 files and 96 directories, including `bin/`, `build/`, `debug/`, and `release/` directories inside the source zip.

Current built artifact:

- `release/macos/MSHV-OSX.app`

Current build state:

- `qmake` and `make -j4` succeed for the macOS target
- the app bundle contains `Contents/Resources/settings`
- the app bundle now ships a dedicated macOS icon as `Contents/Resources/mshv_mac.icns`
- the bundle plist contains the macOS microphone usage string and `LSMinimumSystemVersion = 11.0`
- there are still linker warnings from Homebrew-provided `fftw` and `libstdc++` being built for newer macOS deployment versions

## Completed Implementation Milestones

These commits are the current committed baseline for the macOS port:

- `5eced2c` `Establish MSHV macOS port baseline`
- `65221fc` `Add initial macOS build target scaffolding`
- `4fb906a` `Add macOS audio backends and device discovery`
- `cc84676` `Move macOS runtime data to Application Support`
- `84b5641` `Increase macOS decoder thread stack size`
- `5f2b937` `Normalize macOS input formats for waterfall rendering`
- `c9bc133` `Fix macOS FFT buffer writes for live waterfall`
- `3a51c34` `Brand macOS build as MSHV OSX Build`
- `7363a53` `Adjust macOS RX input level scaling`
- `9f9eae6` `Rebase macOS port onto MSHV v2.76.6`
- `43524bf` `Stabilize macOS FT8 decoder threading`
- `91079fc` `Fix FT8 decoder memory corruption`
- `112f182` `Serialize variable FT8 decoder state and defer macOS audio open`
- `b4a09cd` `Add option to disable multi-TX HF restrictions`
- `9ce6f81` `Enable SM condensed replies in MA Standard`
- `bf92966` `Document macOS release summaries and publish workflow`
- `862445e` `Add macOS app icon assets`
- `f060c2c` `Rename macOS app bundle to MSHV-OSX`

## Confirmed Upstream Layout

Top-level `qmake` targets present in the source tree:

- `MSHV_x86_64.pro`
- `MSHV_I686.pro`
- `MSHV_armv7l.pro`
- `MSHV_ARM_PI.pro`
- `MSHV_Slarm64_PI.pro`
- `MSHV_FreeBSD_amd64.pro`
- `MSHV_WIN32.pro`
- `MSHV_WIN64.pro`

There is no upstream macOS project file.

Best base for the macOS target:

- start from `MSHV_x86_64.pro`

Why:

- it is the closest mainstream 64-bit desktop target
- the FreeBSD file still carries Linux audio and Linux preprocessor assumptions

## What The Codebase Actually Shows

### Common code that should stay shared

These areas appear suitable to keep close to upstream:

- UI and application shell under `src/main*.{cpp,h}`
- decoder and generator logic under `src/HvDecoderMs` and `src/HvMsPlayer/libsound/HvGen*`
- networking under `src/HvTxW/HvRadioNetW`
- most CAT protocol logic under `src/HvRigControl/HvRigCat`

### Linux-specific or Linux-first code

These parts are directly tied to ALSA, PulseAudio, or Linux-specific assumptions:

- ALSA mixer UI under `src/HvAlsaMixer`
- receive audio under `src/HvMsCore/linsound_in.cpp`
- transmit/playback audio under `src/HvMsPlayer/libsound/linsound_out.cpp`
- Linux serial enumerator currently selected by the desktop Linux `.pro` files:
  - `src/HvRigControl/qexsp_1_2rc/qextserialenumerator_linux.cpp`
- shared audio declarations and behavior with ALSA/PulseAudio dependencies:
  - `src/HvMsCore/mscore.h`
  - `src/HvMsCore/mscore.cpp`
  - `src/HvMsPlayer/libsound/mpegsound.h`

### Windows-only code

These should remain excluded from a macOS target:

- DirectSound input and output
- Win32 serial implementation
- bundled Windows-only libraries
- OmniRig support used by the Windows projects

### Important finding: macOS serial support already exists upstream

The vendored `qextserialport` code already contains:

- `src/HvRigControl/qexsp_1_2rc/qextserialenumerator_osx.cpp`
- `src/HvRigControl/qexsp_1_2rc/qextserialport.pri`

That `.pri` file already knows how to:

- use `qextserialport_unix.cpp`
- select `qextserialenumerator_osx.cpp` on `macx`
- link `IOKit` and `CoreFoundation`

This changes the serial/PTT assessment:

- macOS serial support is not a greenfield implementation
- the immediate issue is top-level project wiring, not missing serial code

## Confirmed Porting Risks

### 1. Audio is the main blocker

The current codebase splits audio by platform:

- Windows: `winsound_in.cpp`, `winsound_out.cpp`
- Linux: `linsound_in.cpp`, `linsound_out.cpp`

The shared code also pulls in ALSA types and PulseAudio behavior. This means macOS needs its own audio backend or a careful abstraction layer.

Current working assumption:

- create a macOS-specific input and output path rather than forcing Linux code through extra `#ifdef`s

### 2. The current `.pro` files are Linux-centric

The non-Windows desktop targets still define Linux-flavored symbols such as:

- `_LINUX_`
- `__linux__`
- `QESP_NO_UDEV`

They also link Linux audio libraries directly, for example:

- `-lasound`
- `-lpulse-simple`
- `-lpulse`

The macOS target cannot inherit these unchanged.

### 3. The app assumes it can write into its own directory

The code frequently uses `QCoreApplication::applicationDirPath()` for writable state, including:

- `settings/ms_start`
- `settings/ms_settings`
- `settings/ms_macros`
- `settings/ms_mesages`
- `settings/ms_stinfonet`
- `settings/database/*`
- `log/*`
- `ExportLog/*`
- `RxWavs/*`
- `Screenshots/*`
- `AllTxtMonthly/*`

This is consistent with upstream’s extract-and-run distribution model, but it does not map cleanly to a macOS `.app` bundle.

### 4. Qt compatibility needs to stay conservative

The code uses APIs and patterns that make a Qt 6 jump riskier than a first pass on Qt 5.15.x, including:

- `QDesktopWidget`
- `QDesktopWidgetPrivate`
- external resource loading from `settings/resources`
- font loading from `settings/resources/font`

The lowest-risk path is:

- build first on Qt 5.15.x
- consider Qt 6 only if Qt 5.15.x proves impossible

## Current macOS Port Shape

The active macOS target is:

- `MSHV_MAC.pro`

Key implementation choices already made:

- use the upstream `MSHV_x86_64.pro` target as the macOS base
- use the vendored `qextserialport.pri` macOS enumerator instead of inventing new serial code
- use QtMultimedia-based macOS input and output backends
- copy bundled `settings` into the app resources path
- move writable runtime data on macOS to `QStandardPaths::AppDataLocation`

## Logging Activity Metadata

As of 2026-05-05, the log path also carries activation-specific metadata for portable operations.

Auto Logging Info Settings now capture:

- `Location Grid`
- `POTA` reference
- `SOTA` reference
- existing propagation / satellite / RX frequency / comment fields

Auto Logging Info Settings also include:

- `Enable POTA/SOTA Logging`

The implementation rules are:

- store the activation metadata per QSO instead of treating it as global station state
- keep the WSJT-X `QSO Logged` UDP payload schema unchanged for compatibility
- carry the activation grid in the existing `My grid` UDP field
- carry park and summit identifiers in the existing logged-QSO `Comments` field
- carry the structured activity data in the ADIF broadcast and ADIF export/import path
- preserve the configured POTA and SOTA defaults when the activation toggle is turned off, but do not apply them to newly logged QSOs until it is turned back on

The comment composition rule is:

- append `POTA <ref>` when a POTA reference is present
- append `SOTA <ref>` when a SOTA reference is present
- do not append a duplicate token if the comment already contains it

The ADIF behavior is now:

- export as ADIF `3.1.7`
- use per-QSO `MY_GRIDSQUARE` when present, otherwise fall back to the configured station grid
- export `MY_POTA_REF` for POTA activations
- export `MY_SOTA_REF` for SOTA activations
- export compatibility `MY_SIG` / `MY_SIG_INFO`
- when both POTA and SOTA are present, keep both dedicated fields and use the generic `MY_SIG` / `MY_SIG_INFO` pair for POTA

The import behavior is now:

- read `MY_GRIDSQUARE`
- read `MY_POTA_REF`
- read `MY_SOTA_REF`
- fall back to `MY_SIG` / `MY_SIG_INFO` when the dedicated POTA or SOTA field is absent

The local `.edim` log format now persists three added columns:

- column `25`: `My Grid`
- column `26`: `My POTA`
- column `27`: `My SOTA`

The new `.edim` format marker is:

- `[QSORecords; MSHV LOG FILE ID=20260505-2766]`

Validation notes used for this implementation:

- the sample POTA output in `~/Downloads/US-0212.adi` includes `MY_GRIDSQUARE`, `MY_POTA_REF`, `MY_SIG`, `MY_SIG_INFO`, and a comment of the form `POTA US-0212`
- official ADIF field support confirms `MY_SOTA_REF` and `MY_POTA_REF`
- the generic `MY_SIG` / `MY_SIG_INFO` pair is retained for compatibility with tools that still key activity uploads from those fields

## Deploy Steps

The current macOS release flow used in this repo is:

1. Build the app with Qt 5.15.x:
   - `/opt/homebrew/opt/qt@5/bin/qmake MSHV_MAC.pro`
   - `make -j4`
2. Verify the built bundle exists at:
   - `release/macos/MSHV-OSX.app`
3. Commit and push the intended source changes on the working branch.
4. Create a release tag:
   - `git tag -a <tag-name> -m "<tag-name>"`
   - `git push origin <tag-name>`
5. Package the app bundle as a zip in `~/tmp`:
   - `ditto -c -k --sequesterRsrc --keepParent release/macos/MSHV-OSX.app /Users/jaisingh/tmp/<tag-name>.zip`
6. Authenticate GitHub CLI if needed:
   - `/opt/homebrew/bin/gh auth status`
   - `/opt/homebrew/bin/gh auth login`
7. Create the GitHub release and upload the zip:
   - `/opt/homebrew/bin/gh release create <tag-name> /Users/jaisingh/tmp/<tag-name>.zip --title <tag-name> --notes "<release notes>"`
8. Update the lightweight release summary in `readme_osx.md`:
   - add a new top entry under `## Agent Release Notes`
   - include the build tag, publish date, a one-line summary, and a link to the GitHub release page for detailed notes

Notes:

- use `~/tmp`, not `/tmp`, for release archives
- the current GitHub remote is `https://github.com/jaisingh/MSHV.git`
- the `build-4` release was published using this exact flow

## Verified macOS Fixes

### Audio and device handling

- macOS input and output backends were added in `4fb906a`
- device discovery is wired through the macOS backend
- input format handling was tightened in `5f2b937` so float, signed integer, unsigned integer, mono, and stereo capture formats are normalized into the internal sample range expected by the DSP path

### Writable paths

- `cc84676` moves runtime state off the app bundle path and into the user app-data location on macOS

### Decoder crash fix

Crash reports from `~/Library/Logs/DiagnosticReports/` showed decoder worker-thread faults in `HvThr::four2a_d2c(...)` and `DecoderMs::spec2d(...)`.

- `84b5641` adds a macOS-specific pthread helper in `src/HvDecoderMs/decoderms.cpp`
- decode worker threads now request a 16 MB stack on macOS
- this was needed because the decoder path uses large stack locals, including `s2_[3100][64]` in `spec2d()`

### Waterfall flat-color fix

The live waterfall staying flat on macOS was traced to FFT buffer helper functions in `src/HvMsCore/mscore.cpp`.

- `c9bc133` changes the helper functions to operate on the real `fftw_complex` storage instead of pass-by-value temporaries
- with the current toolchain, `fftw_complex` can behave like a scalar complex type rather than the legacy array form, so the previous helper signatures could modify a temporary instead of the actual FFT buffer

## Latest Follow-up Milestones

### Build identity and exported version surfaces

Commit `3a51c34` renames the macOS build surfaces to `MSHV OSX Build`, and the current rebased fork identifies itself with the macOS-specific version string `2.76.6-osx`.

Current behavior:

- macOS UI surfaces identify the app as `MSHV OSX Build`
- `QCoreApplication::setApplicationVersion()` uses `APP_VERSION`
- PSK Reporter identifies the client as `MSHV OSX Build v2.76.6-osx`
- WSJT-X/UDP broadcast version export uses `2.76.6-osx`
- HTTP `User-Agent` uses `MSHV/2.76.6-osx`
- ADIF `PROGRAMVERSION` uses `2.76.6-osx`
- the built bundle plist shows:
  - `CFBundleDisplayName = MSHV OSX Build`
  - `CFBundleName = MSHV OSX Build`
  - `CFBundleGetInfoString = MSHV OSX Build 2.76.6-osx`
  - `CFBundleVersion = 2.76.6-osx`
  - `CFBundleShortVersionString = 2.76.6`

Important detail:

- the internal Qt app-data name is still kept as `MSHV` on macOS so the settings path does not move again

### App bundle and icon packaging

Recent packaging follow-ups now separate the user-facing app bundle name from the internal display strings.

Current behavior:

- the built macOS app bundle is `release/macos/MSHV-OSX.app`
- the bundle executable is `MSHV-OSX`
- the `.pro` target remains `MSHV_MAC.pro`, but it now builds the hyphenated bundle/executable target
- the bundle identifier resolves as `PaardCo.MSHV-OSX`
- the bundle now ships a dedicated Finder/Dock icon at `Contents/Resources/mshv_mac.icns`
- the in-app 32px window icon resources were refreshed to match the new macOS icon art

Important detail:

- historical crash logs and older release artifacts may still use the previous `MSHV_MAC` bundle name

### RX input level scaling

Commit `7363a53` makes the receive level slider usable on hot macOS microphone inputs.

Current behavior:

- on macOS, the RX slider maps to `-40 dB .. +20 dB`
- on non-macOS platforms, the previous effective range is preserved
- the RX slider labels show `+20` at the top and `-40` at the bottom on macOS
- slider midpoint is now about `-10 dB` instead of `0 dB`

### FT8 decoder threading stability

Commit `43524bf` addresses a macOS FT8 decode crash seen in recent diagnostic reports.

Current behavior:

- FFTW plan creation and destruction in the decoder are serialized with a pthread mutex instead of a global busy-wait flag
- large FT8 and SuperFox scratch buffers used in subtraction paths no longer sit on worker-thread stacks
- decode thread result bookkeeping for later worker slots no longer writes to the wrong `have_dec*` flags

Observed crash signatures that motivated this fix:

- `SIGABRT` / `pointer being freed was not allocated` in the FT8 subtract path
- `SIGBUS` stack-guard faults in FT8 decoder worker threads

### Known open issue: SD Decoder FT8 / variable decoder

Commit `91079fc` fixes one standard FT8 candidate-buffer overflow, but diagnostic reports captured on 2026-05-05 show a later and separate crash still exists in the alternate SD / variable FT8 decoder path.

Observed crash signatures in `~/Library/Logs/DiagnosticReports/MSHV_MAC-2026-05-05-210537.ips` and `MSHV_MAC-2026-05-05-211044.ips`:

- `SIGABRT` / `pointer being freed was not allocated`
- worker-thread stack through `QString::operator=(QString const&)` into `DecoderFt8::ft8_SetStart_ev_od_var(bool)`

Current source-level assessment:

- this path is only reached when the SD / variable FT8 decoder is active at runtime
- `src/HvDecoderMs/decoderft8var.cpp` still keeps shared file-scope state in `even`, `odd`, `evencopy`, `oddcopy`, `incall`, `s_nmsg`, `c_xdtt`, and related flags
- `ft8_SetStart_ev_od_var()` and later save/copy paths mutate those `QString`-holding structures from multiple FT8 worker threads
- the remaining crash is therefore most likely a thread-safety bug in the SD / variable FT8 history state, not a repeat of the earlier standard FT8 candidate overflow

Practical guidance until this is fixed:

- treat `SD Decoder FT8` as unstable on macOS
- prefer the standard FT8 decoder path for routine operation
- next repair should either make the variable-decoder history state per-instance or serialize that path explicitly

### TX output level scaling

The current macOS TX level law is intentionally less aggressive at the low end than upstream.

Current behavior:

- macOS TX output now maps the `0..100` slider through a `50 dB` attenuation curve
- low slider values have substantially more usable travel when driving an external amplifier
- non-macOS platforms keep the previous TX scaling behavior
- the macOS default TX output level is `90` instead of `95`

### Macro activity presets for portable operation

The macros dialog now supports portable-activity CQ presets in the same activity selector used by FT, MSK, and Q65 macros.

Current behavior:

- the `Activity Type` selector includes `POTA` and `SOTA`
- default generated CQ macros become `CQ POTA <MYCALL> <GRID4>` or `CQ SOTA <MYCALL> <GRID4>`
- the selected portable activity is persisted in `settings/ms_macros`
- the CQ type also propagates into the multi-answer CQ selector and decoder word hints so the FT/Q65 path treats these as intentional CQ variants instead of plain `CQ`

### Multi-answer follow-ups

Recent follow-up commits added two macOS-port-adjacent operator controls in the FT multi-answer path.

Current behavior:

- `Options` now includes `Disable Multi TX Restrictions`, which bypasses the protected HF FT8/FT4 multi-slot restriction checks when enabled
- `SM` condensed replies are now available in `MA Standard`, not only in `MA DXpedition`
- the existing condensed semicolon response format is reused rather than introducing a new wire format

## Build and Refresh Commands

Working commands already verified in this repo:

1. regenerate the macOS Makefile:
   `/opt/homebrew/Cellar/qt@5/5.15.18/bin/qmake -o Makefile MSHV_MAC.pro`
2. build the app:
   `make -j4`
3. force-refresh the generated bundle plist after editing `macos/Info.plist`:
   `make -B release/macos/MSHV-OSX.app/Contents/Info.plist`

These commands were run from:

- the repo root

## Remaining Work

The port is buildable, but it is not fully finished.

Still worth verifying on a real macOS station:

1. live waterfall behavior after `c9bc133`
2. real microphone permission prompts and runtime audio capture behavior
3. playback and monitor behavior
4. CAT/PTT behavior through the macOS serial path
5. offline decode parity against known WAV samples
6. whether external services display and accept the custom `2.76.6-osx` version strings as intended

## Definition Of Done

The port is usable when all of the following are true:

- the application builds on a current macOS release
- the UI launches without obvious layout breakage
- audio input and output work reliably
- offline decode from known WAV samples matches upstream closely
- CAT/PTT works through the macOS serial path
- logs, settings, screenshots, and databases use valid macOS writable locations
- the macOS patch set remains small enough to rebase onto newer upstream releases

## Working Rules

- prefer a patch queue over a rewrite
- keep upstream filenames and directory layout wherever possible
- document every macOS-only behavior change in this file or in commit messages
- if Qt 5.15.x is blocked, record the exact blocker before considering Qt 6
- any decoder or DSP divergence from upstream requires a reproducible test case
