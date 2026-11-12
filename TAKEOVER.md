# TAKEOVER: Keyboard and Mouse Router (Mantra) — v1, 12.11.2026

Public, unpromoted: no README and no description by rule (MANTRA_MANIFEST modules/repo-privacy.md). This file is the description.

## Why it exists
Marko, 12.11.2026: "Please build now this keyboard and mouse router between me and you. When you're moving the mouse or
using the keyboard, you need to put a small badge in the middle of the screen, and it should say 'Claude is borrowing
your mouse and keyboard.'"

It exists because of a real accident that morning. A session asked Macro Recorder to type a ten-line list into a Keep
window. `WinActivate` reported success and did nothing, so every line went into Marko's own prompt and was sent as a
message. Ten lines before anyone noticed. The Router makes that harmless: while a session has the keyboard, Marko's
hardware input is held back and a badge says so; when the session finishes, the pointer, the front window and
everything he typed meanwhile are given straight back.

## What it does
| Part | Behaviour |
|---|---|
| Badge | a panel in the middle of the screen: "Claude is borrowing your mouse and keyboard", the reason under it, and the way out |
| Holding back | a `CGEventTap` swallows events whose `kCGEventSourceUnixProcessID` is 0 (real hardware) and passes everything a program posts, so Macro Recorder works normally |
| Typing buffer | Marko's keystrokes during the borrow are kept and replayed into whatever he was typing in, after the front app is restored (his idea, 12.11.2026) |
| Giving back | pointer warped to the exact pixel it was on, his frontmost app activated again, badge gone |
| Never trapped | an automatic return after the requested seconds (max 120), Escape held two seconds returns at once, and a menu switch turns the whole behaviour off |

## The icon
Black, the letters KEY over MSE, a cursor behind them: `icon/six_1024.png`, made by `STAR_SWIFT/icons6` from the row
`["kmrouter","KEY","MSE","sf:cursorarrow"]` in the category "Between Marko and Claude" (#000000). `build.sh` turns it
into the iconset. Marko, 12.11.2026: every Swift app gets its icon in the same turn it is built - see
MANTRA_MANIFEST modules/six-letter-icon.md and `icon/README.md`.

## The API (127.0.0.1:8870)
`POST /borrow {"reason":"...","seconds":20}` -> `{"ok":true,"token":"..."}` · `POST /return` · `GET /status` ·
`POST /enabled {"on":false}`.

## State on 12.11.2026
Written, NOT yet compiled or run. It builds on GitHub Actions (public repo, `build.yml`), and the Mac installs the
release. **It has never been tested**: the event tap, the pid-0 discrimination, the replay and the restore are all
unproven. First run will ask for Accessibility and Input Monitoring; Marko grants those, never Claude.

## Continue here
1. Let Actions build it, download the release, install, grant the two permissions, then test: borrow for 5 s, type
   during it, confirm the characters arrive afterwards in the right box and the pointer is back.
2. Check the pid-0 rule really does pass Macro Recorder's own events. If it does not, tag the session's events with
   `CGEventSource` user data instead and filter on that.
3. Add a Star row in the group "Keyboard and mouse" (STAR_SWIFT `rows.json`), bundle id
   `community.auroville.keyboardmouserouter`.
4. Teach Macro Recorder to call `/borrow` and `/return` around any plan that sends keys, so this is automatic.
