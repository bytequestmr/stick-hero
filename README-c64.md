# Stick Hero C64 port

This is a small Commodore 64 text-mode adaptation of the core game in
[`bytequestmr/stick-hero`](https://github.com/bytequestmr/stick-hero): hold
joystick 2's fire button to grow a stick, release it to turn the stick, and
cross the gap to the next platform. A center hit is worth two points; other
successful landings are worth one. Missing a platform ends the game.

The JavaScript Canvas graphics and animation have been adapted to the C64's
40-column character display. The port copies the C64 character ROM into RAM
and replaces a small set of glyphs with layered grass and stone platforms,
curved hills, rounded clouds against a cyan sky, and fuller, layered tree
canopies. The hero and pixel-precise stick are VIC-II hardware sprites. The
stick starts at the hero's right side and draws in front of the scenery.
Cherries occasionally appear over the path; reaching one adds five points. To
keep the port responsive, the platforms are recentered after each successful
crossing rather than scrolling a full scene.

## Build and run

The prebuilt `stickhero-c64.prg` can be loaded directly in a C64 or emulator.
To rebuild it from source:

1. Install the ACME 6502 assembler.
2. Assemble `stickhero-c64.asm`:

   ```text
   acme stickhero-c64.asm
   ```

   This recreates `stickhero-c64.prg` in the current directory.
3. Load the PRG from disk or an emulator, then run it with `RUN`.
4. Use joystick port 2. Hold fire to grow the stick and release to place it.
   After a miss, press fire to restart, release it, then press again to grow
   the stick.

The game disables KERNAL interrupts while it runs because the KERNAL IRQ
handler reuses zero-page memory used by the game's indirect pointers. Reset the
C64 to return to BASIC.

The source emits a BASIC `SYS 2061` loader, so it can also be started directly
with `SYS 2061` after loading.

The current score and best score are shown at the top. The best score is kept
in RAM across rounds and game-over restarts, and resets when the program or C64
is restarted.

## License

This port is provided under the MIT License, following the upstream project's
license. The upstream project credits Richard S. Goshen Jr. (Copyright
(c) 2023); its license text is in the repository's `LICENSE.md`.
