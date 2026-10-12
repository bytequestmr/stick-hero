# Stick Hero Enhanced V1.4 - C64 port

This is a small Commodore 64 text-mode adaptation of the core game in
[`bytequestmr/stick-hero`](https://github.com/bytequestmr/stick-hero): hold
joystick 2's fire button to grow a stick, release it to turn the stick, and
cross the gap to the next platform. A center hit is worth two points; other
successful landings are worth one. Missing a platform ends the game.

Enhanced V1.4 overlaps adjoining expanded stick segments by one pixel and
compensates the final pixel-masked segment so the stick still ends at its exact
gameplay length. A hero who reaches the far platform while ducking falls.
Sticks that are too short or extend past the far edge also cause a fall. Game
Over is highlighted in red, accompanied by a loud SID noise, and the hero falls
over. Cherries appear
beneath the placed stick; tap fire while walking to duck below it and tap again
to return above it. The hero sprite is slimmer than in the previous version.

The JavaScript Canvas graphics and animation have been adapted to the C64's
40-column character display. The port copies the C64 character ROM into RAM
and replaces a small set of glyphs with layered grass and stone platforms,
curved hills, rounded clouds against a cyan sky, and fuller, layered tree
canopies. The clouds are consistent VIC-II sprites, and both the cloud and
tree positions change with each new scene. The slim hero and pixel-precise
stick are VIC-II hardware sprites.
The stick starts at the hero's right side and draws in front of the scenery.
Cherries occasionally appear beneath the placed stick; collecting one while
ducking underneath adds five points and plays a three-voice SID chord. The
stick's pitch rises as it grows, a short
placement tone plays when released, and a melody accompanies the hero as they
cross the stick. The hero advances smoothly in two-pixel sprite steps, with
melody timing independent from movement; the cherry chord also runs without
pausing the game loop. Horizontal stick sprites overlap at their seams, and
the last sprite is masked to the exact remaining pixel length. The walking
animation stops at the near edge of the target platform. Landing is checked
against the stick's pixel position and the platform's exact edges.
To keep the port responsive, the platforms are recentered after each successful
crossing rather than scrolling a full scene. The distant hills and clouds shift
to new positions as each scene is drawn, giving each crossing a slightly
different background.

## Build and run

The prebuilt `stickhero-enhanced-v1.4-c64.prg` can be loaded directly in a C64
or emulator.
To rebuild it from source:

1. Install the ACME 6502 assembler.
2. Assemble `stickhero-enhanced-v1.4-c64.asm`:

   ```text
   acme stickhero-enhanced-v1.4-c64.asm
   ```

   This creates `stickhero-enhanced-v1.4-c64.prg` in the current directory.
3. Load the PRG from disk or an emulator, then run it with `RUN`.
4. Use joystick port 2. Hold fire to grow the stick and release to place it.
   A cherry may appear as the stick starts to grow; it tracks the stick's
   midpoint. While walking, tap fire to duck under the stick for the cherry
   and tap fire again to return above it. After a miss, press fire to restart,
   release it, then press again to grow the stick.

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
(c) 2023); see `LICENSE-c64.md` for the license text.
