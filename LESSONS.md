# LESSONS: Keyboard and Mouse Router (Mantra)

- **12.11.2026, the accident this app is for.** `WinActivate` in Macro Recorder returns success without raising the
  window. Ten typed lines went into Marko's own prompt and were sent. Never send a keystroke without checking the
  frontmost app immediately before, and never let a session hold the keyboard silently.
- **12.11.2026, `BlockInput` in Macro Recorder is a no-op.** It is accepted by the script engine and mapped to a
  function that does nothing (`Script.swift`, the list at line ~1741). Anything that needed real blocking had to be
  built here.
- **12.11.2026, hardware against synthetic.** A real key or click carries `kCGEventSourceUnixProcessID == 0`; an event
  posted by a program carries that program's pid. That is the discriminator the tap uses so it can hold Marko back
  while letting Macro Recorder through. Unproven in practice - verify on the first run.
- **12.11.2026, never trap the user.** Any app that swallows input must have three ways out that do not need a working
  session: a timeout, a key held down, and a switch. All three are in v1.
