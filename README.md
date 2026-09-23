# 📞 Phone Number Validator GUI

## 📋 Executive Summary

A PowerShell + WPF desktop tool for checking whether a phone number is valid,
what type of line it is, how it should be formatted, and its time zone/region
— for a selected country, **entirely offline** once set up. It does **not**
do reverse lookups (owner name, live carrier, spam scoring) — those require
paid, live, network-based services and raise data-protection questions this
tool deliberately stays out of. Supports single-number checks and batch
checking a list of numbers with CSV export. Built on `libphonenumber-csharp`
(the same engine Android/Chrome use for phone number validation).

## ✅ What It Does

- Country dropdown (United Kingdom and United States pinned to the top,
  ~20 other common countries listed below).
- Type a number and it auto-formats as you go (national grouping, e.g.
  spaces/hyphens as you'd expect for the selected country).
- The number box shows a live example/placeholder for the selected country
  so you know the expected shape before typing.
- Press **Enter** or click **Check Number** to see:
  - **Valid** — Yes/No
  - **Number Type** — Mobile, Landline, VoIP, Toll-Free, Premium Rate, etc.
  - **National Format** (with a Copy button)
  - **International Format** (E.164, e.g. `+44 20 7946 0958`, with a Copy button)
  - **Time Zone(s)** — IANA time zone(s) the number maps to, where available
  - **Region** — an offline geographic description where the library's data
    supports it (varies by country: city, state/region, or just the country
    name)
  - **Notes** — plain-language flags when relevant: number is not even
    possible for the selected country, is possible-but-not-a-real-range
    (a common trait of spoofed caller ID), is a VoIP line (cheap to spoof,
    identity unverifiable from the number alone), or is Premium Rate
    (extra charges to call/return).
- The last country you used is remembered between runs.
- **Batch Check...** opens a second window: paste a list of numbers (one per
  line, optionally `number,COUNTRYCODE` to override the default country per
  line), run them all at once in a results grid, and export to CSV.

## 🚫 What It Deliberately Does NOT Do

This is **not** a reverse lookup tool. It cannot tell you who owns a number,
and there's no reliable offline way to flag a number as "spam" — real spam
detection depends on live, crowd-sourced reporting (Truecaller, Hiya, carrier
STIR/SHAKEN attestation), which has no offline equivalent. The Notes field
above surfaces a couple of honest offline *proxies* (VoIP, possible-but-invalid)
with plain caveats, rather than pretending to give a verdict.

It also does not show **carrier**, because carrier data only reflects the
number range's *original* assignment — in the UK, US, and most countries,
numbers get ported between carriers all the time, so an offline carrier
lookup is frequently wrong. A live/accurate carrier lookup would require a
paid API (e.g. Twilio Lookup) that queries the network in real time.

Caller ID name (CNAM) — the business/person name registered against a number
— is US/Canada-only infrastructure, requires a paid API, and for private
individuals raises UK GDPR/PECR questions that are outside what this tool
should quietly enable. None of that is built in.

## ⚙️ How It Works

Built on [`libphonenumber-csharp`](https://github.com/twcclegg/libphonenumber-csharp),
the C# port of Google's libphonenumber library — the same validation engine
used by Android, Chrome, and many carriers. All of its metadata (validation
rules, formatting rules, and geocoding data) is compiled into the assembly
itself, so lookups never touch the network or read files at runtime.

## 🔧 One-Time Setup

The first time you run the script, it downloads the small `libphonenumber-csharp`
assembly (and, on Windows PowerShell 5.1 only, two small companion .NET
assemblies) directly from `nuget.org` into a `lib\` folder next to the
script. This requires internet access **once**. Every run after that is
fully offline — nothing is downloaded, and no data ever leaves your machine.

If your machine has no direct internet access (e.g. isolated client
environment), run the script once on a machine that does, then copy the
whole folder (script + the generated `lib\` subfolder) across — it will
detect the cached files and skip the download.

## ▶️ Usage

```powershell
.\PhoneNumberValidatorGUI.ps1
```

Works on both Windows PowerShell 5.1 and PowerShell 7+.

## 📦 Batch Mode Input Format

Each line in the batch box is one of:

```
+44 20 7946 0958
020 7946 0958
+1 415 555 0100,US
07946 123456,GB
```

If no country is given after the comma, the "Default country" dropdown in
the batch window is used for that line. Results appear in a grid and can be
exported with **Export to CSV...**.

## 🌍 Adding More Countries

Countries are defined near the top of the script as a simple list of
`'Country Name' = 'ISO-3166 two-letter code'` pairs — add a line to extend
the dropdown (it drives both the single-check and batch-check dropdowns).

## 📝 Notes

- `libphonenumber-csharp`'s validation/formatting accuracy depends on how
  current its bundled metadata is (Google updates it roughly every two
  weeks). If a very recently-issued number range shows as invalid, that's
  likely why — re-running the one-time download against a newer package
  version would refresh it (delete the `lib\` folder and re-run the script).
- The as-you-type formatter re-formats the whole box on every keystroke and
  moves the cursor to the end each time — fine for typing a number in one
  go, slightly clunky if you edit digits in the middle of an existing entry.
- Settings (last-used country) are stored in `settings.json` next to the
  script.
