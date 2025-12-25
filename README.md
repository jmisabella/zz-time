# zz-time

A minimalist iOS meditation and sleep app with 35 ambient audio environments and optional guided meditations.

## Features

### Core Audio Experience
- **35 Looping Audio Files** across 4 styles:
  - White noise
  - Dark ambient
  - Bright ambient
  - Classical compositions
- **Flexible Duration**: Set specific time or infinite loop
- **Smart Fade**: Fade to silence or transition to wake-up music
- **100% Offline**: No internet required, fully private

### Guided Meditations
- **35 Pre-written Meditations**: Random guided meditation toggle
- **Custom Meditations**: Write and save up to 35 custom meditations
- **Pause Markers**: Add timed pauses like `(2s)` or `(1.5m)` to your meditations
- **Closed Captions**: Optional text display of spoken meditation (enabled by default)

### Voice Options
- **Default Voice (Included)**: Intentionally artificial, robotic quality that creates a unique meditative atmosphere - no downloads needed
- **Enhanced Voices (Optional)**: Natural-sounding iOS system voices available through in-app settings
  - Many pre-installed on newer devices (iPhone 16, etc.)
  - Some require download (100-500MB each)
  - Managed through iOS Settings → Accessibility → Spoken Content → Voices
  - Access via gear icon inside rooms (leftmost button)

### App Philosophy
- **100% Free**: No ads, no subscriptions, no in-app purchases
- **Privacy First**: Completely offline, no tracking, no data collection
- **Lightweight**: ~110MB app size (enhanced voices stored separately by iOS)
- **Minimal Design**: Clean, distraction-free interface

## Usage

1. Select one of 35 ambient rooms from the main grid
2. Set duration or choose infinite
3. Optionally toggle guided meditation (leaf button)
4. Optionally access voice settings (gear button inside room)
5. Drift off to ambient sounds with optional meditation guidance

## Technical Details

- **Platform**: iOS (Swift/SwiftUI)
- **Audio**: Looping ambient files with fade controls
- **TTS**: AVSpeechSynthesizer with dynamic voice selection
- **Storage**: UserDefaults for preferences, system-level for enhanced voices
- **Size**: ~110MB (app only, enhanced voices managed by iOS)

## Recent Updates

### Version 2.5 (December 2025)
- Added optional enhanced voice quality feature
- Dynamic speech rate (0.8x for default, 1.0x for enhanced voices)
- Voice settings accessible inside rooms
- Many enhanced voices pre-installed on newer devices
- Full storage transparency and management instructions