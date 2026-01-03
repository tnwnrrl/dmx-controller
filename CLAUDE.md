# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Processing-based DMX controller for multi-device stage lighting. Controls 30 DMX channels across 5 device types via serial communication with Arduino DMX interface.

## Running the Application

**Processing App**:
1. Open `dmx.pde` in Processing IDE
2. Run with Cmd+R (Mac) / Ctrl+R (Windows)
3. Serial port: `/dev/tty.usbmodem11301` at 115200 baud (update in `setup()` if needed)

**Arduino DMX Interface**:
1. Open `arduino_dmx/arduino_dmx.ino` in Arduino IDE
2. Install DMXSerial library (Library Manager → "DMXSerial")
3. Upload to Arduino Leonardo/Uno with MAX485 module

## Architecture

### File Structure
- `dmx.pde` - Main Processing application (~2800 lines)
- `arduino_dmx/arduino_dmx.ino` - Arduino DMX output controller
- `data/sequence.json` - Keyframe sequence persistence
- `data/video.mp4` - Timeline video file

### Core Systems

**1. DMX Channel System (30 channels)**
- `dmxChannels[30]` array stores current state (0-255 per channel)
- `channelNames[30]` and `defaultChannelValues[30]` for metadata
- Serial protocol: `CH{channel}={value}\n` (e.g., `CH19=255\n`)

**2. Tabbed UI System (8 tabs)**
- Position, Light, Gobo, Beam, Effects (Moving Head CH1-18)
- PAR (RGBW PAR Light CH19-25)
- Ellip (Ellipsoidal Lights CH26-29)
- Fog (Fog Machine CH30)

Each tab follows pattern:
- `draw{Tab}Tab(yPos)` - rendering
- `handle{Tab}Clicks(yPos)` - mouse click events
- `handle{Tab}Drags(yPos)` - mouse drag events

**3. Video Timeline Sequencer**
- `Keyframe` class: timestamp, dmxValues[30], interpolateToNext
- `timeline` ArrayList maintains sorted keyframes
- `updateDMXFromTimeline()` syncs playback to video time
- Delta-only DMX updates for 60 FPS performance

**4. State Synchronization**
- `updateDMXChannel(channel, value)` - updates array + sends DMX
- `syncUIFromDMX()` - rebuilds UI variables from dmxChannels[]

## DMX Channel Map

| DMX | Device | Channels |
|-----|--------|----------|
| 1-18 | Moving Head | Pan, Tilt, Speed, Dimmer, Strobe, Color, Gobo, Focus, Zoom, Prism, Frost, Auto |
| 19-25 | RGBW PAR | Dimmer, R, G, B, W, Strobe, Auto/Sound |
| 26-27 | Ellip 1 | Dimmer, Strobe |
| 28-29 | Ellip 2 | Dimmer, Strobe |
| 30 | Fog Machine | Output |

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| K | Add keyframe at current time |
| S | Save keyframe changes |
| Delete | Delete selected keyframe |
| Spacebar | Play/pause video |
| F1-F12 | Recall preset |
| Shift+F1-F12 | Save preset |

## Key Functions

**DMX Control**:
- `sendDMX(channel, value)` - Serial output to Arduino
- `updateDMXChannel(channel, value)` - Update + send

**Keyframe System**:
- `addKeyframe()` - Capture current state
- `applyKeyframe(kf)` - Apply keyframe (delta-only)
- `interpolateKeyframes(kf1, kf2, t)` - Linear blend
- `saveSequence(filename)` / `loadSequence(filename)` - JSON persistence

**UI Helpers**:
- `drawSlider(x, y, w, label, value, min, max)` - Horizontal slider
- `drawVerticalSlider(...)` - Vertical slider
- `drawValueBox(x, y, value, label)` - Clickable numeric display
- `drawCheckbox(x, y, label, checked)` - Toggle control

## Layout Constants

```
Window: 1400x800px
Tab content: Y=110
DMX Monitor: Y=480, H=140
Timeline: Y=630, H=120
Margin: 30px
Tab width: 120px (8 tabs)
```

## Development Notes

- User prefers Korean comments
- Slider click areas: 45-50px height for usability
- Keyframe markers: 16px triangles, 10px click tolerance
- Backward compatible JSON loading (18ch → 30ch)
