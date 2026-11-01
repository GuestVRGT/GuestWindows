# Guest Windows

A from-scratch x86 PC emulator for iPadOS, written in Swift, with a Safari-based
desktop UI served from a local HTTP/WebSocket server. No QEMU, UTM, or other
existing emulator engine is used.

## Honest current status

This project is a multi-milestone undertaking. **It does not boot Windows 10
yet, and won't for a long time.** Anything claiming otherwise is wrong. What
exists right now:

- [x] **Milestone 1** — iOS app shell, SwiftUI interface, XcodeGen project spec,
      GitHub Actions build pipeline producing an unsigned IPA.
- [x] **Milestone 2 (started)** — General-purpose/segment registers with
      correct x86 sub-register aliasing (EAX/AX/AH/AL), EFLAGS with real
      bit layout and arithmetic flag logic.
- [x] **Milestone 3 (started)** — Flat memory bus, real-mode segment:offset
      linear address translation (with 8086-style wraparound).
- [~] **Milestone 4 (started)** — A fetch-decode-execute loop implementing a
      *small, deliberately limited* instruction subset: `NOP`, `HLT`,
      `MOV r8/r16, imm`, `ADD AL/AX, imm`, `INC`/`DEC r16`, short `JMP`.
      Covered by real unit tests, not placeholders.
- [ ] Milestone 5 — Full real-mode instruction coverage (ModRM addressing,
      memory operands, stack ops, string ops, interrupts).
- [ ] Milestone 6 — Protected mode, segment descriptors, paging.
- [ ] Milestone 7 — BIOS-compatible boot process.
- [ ] Milestone 8 — Virtual disk format + storage controller device.
- [ ] Milestone 9 — VGA graphics device.
- [ ] Milestone 10 — Enough device/CPU fidelity to attempt a Windows 10 boot.
- [ ] Milestone 11 — Local HTTP/WebSocket server (Network.framework).
- [ ] Milestone 12 — Safari desktop UI: screen streaming, touch-to-mouse,
      keyboard, fullscreen.
- [ ] Milestone 13 — Persistent disk storage + app lifecycle (suspend/resume).
- [x] **Milestone 14 (started)** — This GitHub Actions workflow.

Milestones 5 onward are each individually large (a real-mode instruction
decoder covering ModRM addressing alone is a substantial piece of work, and
protected mode + paging is bigger still). Expect this to take a long time,
built in small, independently-tested increments.

## Why XcodeGen instead of a hand-written .xcodeproj

`.xcodeproj` files are fragile when hand-edited and there's no way to open or
repair them without Xcode. Instead, [`project.yml`](project.yml) describes the
project declaratively, and the GitHub Actions macOS runner generates a fresh,
valid `.xcodeproj` from it on every build using
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

## Building (no Mac required)

1. Push this repo to GitHub.
2. GitHub Actions (`.github/workflows/build.yml`) runs automatically on push
   to `main`, or can be triggered manually from the **Actions** tab.
3. The workflow:
   - Installs XcodeGen and generates the Xcode project.
   - Runs the unit test suite on an iPad Simulator.
   - Archives an **unsigned** build (no Apple Developer account needed).
   - Packages it as `GuestWindows-unsigned.ipa`.
4. Download `GuestWindows-unsigned.ipa` from the workflow run's **Artifacts**
   section.
5. Sign and install it with **KSign** on your iPad.

## Project layout

```
GuestWindows/
├── project.yml                      # XcodeGen spec (generates the .xcodeproj)
├── Sources/
│   ├── GuestWindowsApp/             # SwiftUI app target (UI only)
│   └── GuestWindowsCore/            # Emulator core (framework target)
│       ├── CPU/                     # Registers, EFLAGS, interpreter
│       └── Memory/                  # Flat memory bus
├── Tests/
│   └── GuestWindowsCoreTests/       # Real unit tests for the CPU core
├── Resources/                       # Asset catalog
└── .github/workflows/build.yml      # CI build -> unsigned IPA
```

Core emulation logic lives in `GuestWindowsCore`, separate from the UI, so it
can be unit-tested headlessly and reused once device emulation needs a
non-UI execution context (e.g. background-safe stepping).

## Legal

This project does not bundle any Windows installation media or other
copyrighted Microsoft material. Users must supply their own genuine,
licensed Windows 10 ISO.
