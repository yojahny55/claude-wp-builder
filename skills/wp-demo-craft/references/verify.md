# Verify

Adapted from nateherkai/scroll-craft (MIT).

A scroll page cannot be checked by looking at it once. It has no single
state: every scroll position is a different frame, and the failures live
between the two you happened to look at. `/wp-demo-verify` walks it
mechanically and produces a contact sheet; this file is what to read out of
that sheet and how.

## What the machine measures

**Dead scroll**: consecutive positions where nothing changed: no cue opacity
moved, no `--motion-p` advanced, no rail transform travelled, no clip-path
progressed. Real dead scroll means the reader is turning the wheel and being
given nothing. Fix by shortening the section's span or adding a cue.

**Cues that never peak**: an element that never reaches full opacity anywhere
in its section. Usually a cue window too narrow for the section, or ramps
that eat the whole window.

**Horizontal overflow**: at any tested width, content wider than the
viewport.

**Copy clipped by its container**: text cut off by a fixed-height wrapper or
an overflow: hidden ancestor.

**For cinematic demos**, a frozen stage: the video canvas is on screen, the
reader is scrolling, and the playhead is not moving.

## What the machine does not measure

- **Composited contrast.** Read this from the sheet by eye, frame by frame,
  because a headline can clear the contrast floor against one still and fail
  three hundred pixels later against another.
- **Real-device behaviour.** Headless Chrome cannot prove how the page feels
  on an actual phone, on an actual network, under an actual thumb.

## The reading protocol

1. Open `sheet.png` per tested width.
2. Run the feel check from `feel.md` **cold**, before rereading the brief.
3. Confirm the peak is the largest visual change on the page and holds the
   most scroll room.
4. Confirm there is silence in front of the peak, not another loud section.
5. Confirm the last screen can stand still with content on it, not fade to
   nothing.

**A green machine run alone is not a pass.** The machine catches dead scroll,
missed peaks in opacity, overflow and clipping; it cannot tell you whether the
page is any good. Reading the contact sheet is not optional and does not
happen automatically just because `/wp-demo-verify` exited 0.
