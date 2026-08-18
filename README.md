<p align="center">
  <img src="assets/postmark/logo.png" width="120" alt="Postmark logo">
</p>

# Postmark

A camera that turns your photos into postage stamps.

Instead of a feed, you get a stamp book. Point the camera through the machine's
bezel, press the shutter, and the machine presses down and prints a perforated
stamp that ejects out of the slot. Give it a caption, and it goes into the book.

Quiet and non-social by design — no likes, no followers, no sharing. Just a
small collection of moments you chose to keep.

## What you can do

**Print a stamp.** A full-screen viewfinder sits behind a brushed-metal machine
frame; whatever shows through the window is what gets stamped. Flash, pinch to
zoom, and flip between front and back cameras. You can also pull a photo from
your gallery instead of shooting one.

**Add a caption.** A few words to keep with the stamp, or leave it blank.

**Browse the book.** Stamps are grouped by month, newest first. Tap one to see
it full size with its caption and date.

https://github.com/user-attachments/assets/7ae17a25-a770-4292-a7dc-1e651f1fb885

## Getting started

Requires Flutter with Dart SDK 3.12.2 or newer.

```bash
git clone https://github.com/0xLou1s/postmark.git
cd postmark
flutter pub get
flutter run
```

The camera doesn't work on a simulator or emulator — run it on a real device.
It asks for camera and photo library access the first time you print a stamp.

Tests:

```bash
flutter test
```
