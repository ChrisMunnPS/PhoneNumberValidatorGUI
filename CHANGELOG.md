\# 📝 Changelog



All notable changes to Phone Number Validator GUI are documented here.

Versioning follows \[Semantic Versioning](https://semver.org/) (MAJOR.MINOR.PATCH).



\## 🩹 \[1.6.3] — Dark Mode ComboBox Fix



\### Fixed

\- Country names were invisible in the dropdown list (both the main

&#x20; Country combo and Batch Check's default-country combo) when Dark Mode

&#x20; was on. Root cause: a `ComboBox`'s dropdown popup does not automatically

&#x20; follow the `Background`/`Foreground` set on the control itself - that

&#x20; only styles the closed box. The popup list kept its default light

&#x20; background while the text correctly inherited the dark-mode light

&#x20; colour, producing light text on a light background.

\- Fixed with a themed `ComboBox` control template (covering the popup

&#x20; background, border, and each item's hover/selected highlight) applied

&#x20; to both country dropdowns, rather than relying on simple property

&#x20; setters that don't reach the popup.



\## 🩹 \[1.6.2] — Dark Mode Crash Fix (Take 2) + About Window Sizing



\### Fixed

\- \*\*The real root cause of the theme crash, finally isolated.\*\* 1.6.1's

&#x20; fix (constructing brushes with explicit `-ArgumentList`) was necessary

&#x20; but not sufficient - the exact same error persisted with the exact same

&#x20; values, which proved the brushes themselves were valid all along. The

&#x20; actual problem was \*replacing\* a `Window.Resources\\\[key]` entry with a

&#x20; new brush object: doing so forces WPF to immediately re-validate that

&#x20; new value against every element bound to it via `DynamicResource`, and

&#x20; that re-validation path was throwing spurious "not a valid value"

&#x20; errors in this hosting environment (PowerShell 5.1 + Add-Type-loaded

&#x20; WPF), even for genuinely valid brushes.



&#x20; Fixed by switching to the standard WPF pattern for live theme

&#x20; switching: each window's XAML now pre-declares its brushes directly as

&#x20; `Window.Resources` (so they exist the instant the window loads), and

&#x20; switching theme \*mutates the existing brush's `.Color` property in

&#x20; place\* rather than replacing the dictionary entry. Every bound element

&#x20; already holds a reference to that exact brush instance, so the colour

&#x20; change propagates automatically with no re-validation step to fail.

\- \*\*About window's Close button was cut off.\*\* Changed from a guessed

&#x20; fixed `Height` to `SizeToContent="Height"`, so the window always sizes

&#x20; itself to fit its actual content regardless of font rendering or DPI

&#x20; differences, instead of relying on a pixel value that might not hold

&#x20; on every machine.



\### Notes

\- The "missing name boxes" and "dark mode is still tough to read" reports

&#x20; were very likely downstream symptoms of the crash above - errors were

&#x20; interrupting the theme application partway through, leaving some

&#x20; elements styled and others not, producing an inconsistent, partially

&#x20; broken appearance rather than a genuinely bad colour choice. The

&#x20; palette itself is unchanged from 1.6.1 in this release; re-evaluate

&#x20; readability once this fix confirms clean.



\## 🩹 \[1.6.1] — Dark Mode Crash Fix + Palette Rework



\### Fixed

\- Applying either theme crashed immediately with `'#FFE6E6E6' is not a

&#x20; valid value for property 'Foreground'` (and similar, for every themed

&#x20; colour). Root cause: brush construction used

&#x20; `New-Object TypeName(args)` - constructor arguments in parentheses

&#x20; directly after the type name - which looks like a C# constructor call

&#x20; but isn't parsed as one in PowerShell, and doesn't reliably produce the

&#x20; object it looks like it should. Rewrote it using explicit

&#x20; `-ArgumentList` and manual hex-to-byte parsing, removing the ambiguity

&#x20; entirely.

\- The self-healing dependency resolver (added in 1.2.0) was firing for

&#x20; \*every\* unresolved assembly in the process, including PowerShell's own

&#x20; internal resource assemblies, and wastefully trying to fetch them from

&#x20; NuGet. It now only acts on the specific dependency names this script

&#x20; actually uses.



\### Changed

\- Reworked the colour palette using Material Design's dark-theme

&#x20; guidance and verified WCAG AA contrast ratios, rather than first-pass

&#x20; hex guesses:

&#x20; - Dark backgrounds use Material's `#121212` baseline instead of pure

&#x20;   black - pure black next to bright text causes glare and eye strain.

&#x20; - Control/button surfaces step up in lightness from the background

&#x20;   ("elevation"), so raised elements read as raised.

&#x20; - Status colours (valid/invalid/notes/link) use Material's softer

&#x20;   "300"-weight tones in dark mode instead of a brighter version of the

&#x20;   light-mode colour - full-saturation red/green glows uncomfortably on

&#x20;   a dark background.

&#x20; - Every colour's contrast ratio against its paired background is noted

&#x20;   in the code as a comment.



\## 🌓 \[1.6.0] — Dark Mode



\### Added

\- \*\*Dark Mode checkbox\*\* in the main window. Defaults to Windows' own

&#x20; "Apps use dark/light mode" setting (read from the registry) on first run,

&#x20; and remembers whatever you last chose after that (`settings.json`).

&#x20; Applies live across the main, Batch Check, and About windows without

&#x20; needing a restart.

\- Colour palette chosen for WCAG AA contrast (4.5:1+ for normal text)

&#x20; against its paired background in both themes, rather than a straight

&#x20; colour inversion — body text uses near-black/near-white (not pure

&#x20; black/white), and status colours (valid/invalid/notes/links) are shifted

&#x20; lighter for dark mode and darker for light mode, since the same hex

&#x20; value rarely reads well against both a white and a near-black background.



\### Fixed

\- The 📞 in the About window's title was rendering as garbled characters

&#x20; (`ðŸ“ž`) on Windows PowerShell 5.1. Root cause: the script file had no

&#x20; UTF-8 byte-order-mark, so PS 5.1 was reading it with the system ANSI

&#x20; codepage instead of UTF-8, mangling the emoji's bytes. Fixed by

&#x20; encoding the emoji as an XML numeric character reference (encoding-

&#x20; independent) and adding a UTF-8 BOM to the file as a defensive measure

&#x20; against the same issue with any future non-ASCII text.



\### Known limitations

\- Native OS dialogs (the "Setup Failed" and "Check for Updates" message

&#x20; boxes) are unstyled system dialogs and don't follow the in-app theme -

&#x20; reskinning those would mean replacing them with custom WPF windows,

&#x20; which felt like scope creep beyond what was asked here.

\- Some native control chrome (e.g. the checkbox's own tick-box outline,

&#x20; and a ComboBox's open dropdown list on older Windows versions) may not

&#x20; fully match the theme - full control over these needs custom WPF

&#x20; ControlTemplates, which is a much larger undertaking than reskinning

&#x20; Background/Foreground/BorderBrush.



\## ℹ️ \[1.5.0] — About Window



\### Added

\- \*\*"About" button\*\* opens a window showing the app name, current version,

&#x20; author (Chris Munn), and clickable links to the

&#x20; \[portfolio](https://ChrisMunnPS.github.io) and

&#x20; \[repository](https://github.com/ChrisMunnPS/PhoneNumberValidatorGUI).

&#x20; Links open in the default browser.



\## 🆕 \[1.4.0] — Check for Updates



\### Added

\- \*\*"Check Updates..." button.\*\* Manually checks nuget.org for newer stable

&#x20; releases of the library and its dependencies, downloads anything newer,

&#x20; and reports what changed. Nothing is checked automatically — the app stays

&#x20; fully offline unless this is clicked.

\- `lib\\\\versions.json` — a small manifest tracking which version of each

&#x20; dependency is currently installed, so update checks don't need to

&#x20; re-download everything just to compare versions.

\- Window title now shows the app version (e.g. "Phone Number Validator v1.4.0").



\### Notes

\- Because assemblies are already loaded once the app is running, an update

&#x20; only takes effect after restarting the app.



\## ☎️ \[1.3.0] — Carrier (Original Assignment)



\### Added

\- \*\*Carrier (original)\*\* field using the library's offline

&#x20; `PhoneNumberToCarrierMapper`.



\### ⚠️ Known limitation (by design)

\- This reflects the \*original\* block assignment only, not the current

&#x20; carrier. Ported numbers (very common in the UK/US) and MVNOs (e.g. Mint

&#x20; Mobile running on T-Mobile's network, many UK budget networks running on

&#x20; O2's or Vodafone's) will show the wrong or host network. A caveat is

&#x20; auto-added to the Notes field whenever a carrier name is shown.



\## 🔧 \[1.2.0] — Full Dependency Chain + Self-Healing Loader



\### Fixed

\- `System.Runtime.CompilerServices.Unsafe`, `System.Buffers`, and

&#x20; `System.Numerics.Vectors` were missing from the Windows PowerShell 5.1

&#x20; dependency set — only `System.Memory` and `System.Collections.Immutable`

&#x20; were being downloaded, even though those two themselves depend on the

&#x20; other three. All five are now downloaded upfront.



\### Added

\- The assembly resolver now \*\*self-heals\*\*: if a dependency shows up that

&#x20; wasn't anticipated, it attempts to download it automatically (assuming

&#x20; the NuGet package id matches the assembly name, which holds for all the

&#x20; Microsoft BCL polyfill packages in this dependency chain) instead of

&#x20; failing outright.



\## 🩹 \[1.1.3] — Assembly Resolver Scope Fix



\### Fixed

\- The `AssemblyResolve` event handler referenced local variables

&#x20; (`$cacheDirForResolver`, `$resolveInProgress`) that were `$null` when the

&#x20; handler actually fired, because `AssemblyResolve` is raised by the CLR

&#x20; loader directly — not through PowerShell's own event plumbing (unlike WPF

&#x20; `Add\\\_Click`) — so a plain scriptblock cast to a delegate doesn't carry

&#x20; local closures with it. Switched to `$script:`-scoped variables, which

&#x20; resolve correctly regardless of how the delegate is invoked.



\## 💥 \[1.1.2] — Stack Overflow Fix



\### Fixed

\- NuGet version selection was picking the literal last entry in the

&#x20; version list, which can be a prerelease/RC build (a real-world case

&#x20; pulled `System.Collections.Immutable 11.0.0-rc.1...`). Combined with the

&#x20; new resolver, a mismatched forwarding reference caused infinite

&#x20; recursion and a `StackOverflowException` (uncatchable — kills the

&#x20; process outright).

\- Version selection now explicitly excludes prerelease versions (anything

&#x20; containing `-`) and picks the newest stable release.

\- Added a recursion guard to the resolver: a second in-flight request for

&#x20; the same assembly name is refused rather than retried, so any future

&#x20; mismatch fails cleanly instead of crashing the process.



\## 🔗 \[1.1.1] — Assembly Binding Context Fix



\### Fixed

\- On Windows PowerShell 5.1, `PhoneNumberToTimeZonesMapper` and similar

&#x20; calls threw `FileNotFoundException` for `System.Collections.Immutable`

&#x20; even though the file was present in `lib\\\\`. Root cause: `Add-Type -Path`

&#x20; loads assemblies into the "LoadFrom" binding context, so when

&#x20; `PhoneNumbers.dll` (also loaded that way) asked the CLR for its own

&#x20; dependency, normal probing ran in a different context and didn't find it.

\- Added an `AssemblyResolve` handler that hands back the cached copy

&#x20; directly whenever normal binding fails — the standard fix for this class

&#x20; of .NET Framework loading issue.



\## ✨ \[1.1.0] — Feature Expansion



\### Added

\- \*\*Time Zone(s)\*\* field (offline, via `PhoneNumberToTimeZonesMapper`).

\- \*\*Notes\*\* field: plain-language flags for not-possible numbers,

&#x20; possible-but-invalid numbers (common trait of spoofed caller ID), VoIP

&#x20; lines, and Premium Rate numbers.

\- \*\*Live as-you-type formatting\*\* in the number box.

\- \*\*Example number placeholder\*\* text per selected country.

\- \*\*Copy buttons\*\* on the National and International format results.

\- \*\*Enter key\*\* now triggers Check Number, not just the button.

\- \*\*Last-used country remembered\*\* between runs (`settings.json`).

\- \*\*Batch Check\*\* window: paste a list of numbers (optionally

&#x20; `number,COUNTRYCODE` per line), run them all, view results in a grid,

&#x20; export to CSV.



\### Deliberately not added

\- Spam/scam scoring — no honest offline signal exists for this.

\- Emergency-number / short-code detection, and ambiguous multi-country

&#x20; detection (e.g. `+1` spanning US/Canada/Caribbean) — skipped because the

&#x20; exact C# API signatures couldn't be verified against a live install at

&#x20; the time.



\## 🎉 \[1.0.0] — Initial Release



\### Added

\- WPF GUI: country dropdown (United Kingdom and United States pinned to

&#x20; the top, \~20 other common countries below), phone number input, and a

&#x20; results panel.

\- Offline validation, formatting (National / International / E.164), and

&#x20; number type (Mobile / Landline / VoIP / Toll-Free / Premium Rate / etc.)

&#x20; via `libphonenumber-csharp`.

\- Offline region/geocoding description via `PhoneNumberOfflineGeocoder`.

\- One-time setup that downloads the required assembly (and, on Windows

&#x20; PowerShell 5.1, its dependencies at the time) from nuget.org into a

&#x20; local `lib\\\\` cache, so every run after that is offline.



\### Deliberately not built (by design, not oversight)

\- Reverse lookup of the number's owner (person or business) — this is

&#x20; not possible offline in any reliable way, and for private individuals

&#x20; raises UK GDPR/PECR questions outside what this tool should enable.

\- Live carrier lookup — would require a paid API querying the network in

&#x20; real time (offline "original assignment" carrier data was added later,

&#x20; in 1.3.0, with heavy caveats).

