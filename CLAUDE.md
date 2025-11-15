# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Processing-based DMX controller for 18-channel moving head stage lighting fixtures. The application provides a GUI for real-time control of professional lighting equipment via serial DMX communication.

## Running the Application

**Platform**: Processing 3 or 4 (Java-based creative coding environment)

**To run**:
1. Open `dmx.pde` in Processing IDE
2. Click "Run" button or press Cmd+R (Mac) / Ctrl+R (Windows)
3. Serial port is hardcoded to `/dev/tty.usbmodem1201` at 115200 baud - update in `setup()` if needed

**Dependencies**:
- Processing core libraries (built-in)
- `processing.serial.*` library (built-in)

## Architecture

### Single-File Structure
The entire application is in `dmx.pde` (~1300 lines). Processing sketches use a simplified structure where all code runs in a single namespace.

### Core System Components

**1. DMX Channel System (CH1-18)**
- 18-channel DMX fixture profile mapped to UI controls
- `dmxChannels[]` array stores current state (0-255 per channel)
- Channel mapping is fixed (CH1=Pan, CH2=Pan Fine, CH3=Tilt, etc.)
- **No DMX address offset** - currently hardcoded to control DMX addresses 1-18 only

**2. Serial Communication Protocol**
- Format: `CH{channel}={value}\n` (e.g., `CH1=113\n`)
- Sent via `sendDMX(channel, value)` function
- Expects Arduino/DMX interface on serial port
- All commands logged to `commandHistory` for DMX Output Monitor display

**3. Tabbed UI System**
- 5 tabs: Position, Light, Gobo, Beam, Effects
- Each tab has dedicated draw/click/drag handlers:
  - `drawPositionTab()`, `handlePositionClicks()`, `handlePositionDrags()`
  - Same pattern for Light, Gobo, Beam, Effects tabs
- Tab switching via `handleTabClicks()` and `currentTab` variable

**4. Control Patterns**

**XY Pad (Position tab)**:
- 300x300px interactive area for Pan/Tilt control
- Maps mouse position to DMX values with `map()` function
- Supports Fine Mode for 16-bit precision (CH2=Pan Fine, CH4=Tilt Fine)

**Sliders**:
- Horizontal sliders: 40-50px tall click zones for easy interaction
- Vertical sliders: ±20px horizontal margins
- Both click-to-jump and drag supported
- Visual: 30px bar height, 16px handle width, rounded corners

**Value Boxes**:
- Click any value box to enter direct numeric input mode
- `isInputMode` flag activates overlay for keyboard entry
- ESC cancels, Enter confirms
- Validates against min/max range per control

**5. Preset System (F1-F12)**
- 12 preset slots storing full 18-channel snapshots
- F1-F12 keys recall presets
- Shift+F1-F12 saves current state
- Ctrl+F1-F12 renames preset (via input overlay)
- Stored in `presets[][]` 2D array

**6. Event Handlers**
- `mousePressed()` → routes to tab-specific click handlers
- `mouseDragged()` → routes to tab-specific drag handlers
- `keyPressed()` → handles F-keys, input mode, ESC

**7. UI Rendering Functions**
- `drawSlider()` - horizontal sliders with expanded click areas
- `drawVerticalSlider()` - vertical sliders with extended width
- `drawValueBox()` - clickable numeric displays
- `drawCheckbox()` - boolean toggle controls
- All use consistent 30px margins and spacing

## Key Technical Details

**DMX Channel Mapping**:
- CH1: Pan (0-255, maps to 0-540°)
- CH2: Pan Fine (16-bit mode)
- CH3: Tilt (0-255, maps to 0-270°)
- CH4: Tilt Fine (16-bit mode)
- CH5: XY Speed
- CH6: Dimmer
- CH7: Strobe (mode-dependent: 0=off, 255=on, 8-250=strobe speed)
- CH8: Color Wheel (0=white, values select colors, 190+=rotation)
- CH9: Color Effect
- CH10: Static Gobo (0-7)
- CH11: Rotation Gobo (0-6)
- CH12: Gobo Rotation
- CH13-14: Focus, Zoom
- CH15-16: Prism on/off, Prism Rotation
- CH17-18: Frost on/off, Auto Program

**Layout Constants**:
- Window: 1800x750px
- DMX Monitor: Y=480, Height=140px
- Timeline: Y=630
- Presets: Y=710
- Tab content starts: Y=110
- Standard margin: 30px

**State Synchronization**:
- `updateDMXChannel(channel, value)` updates array and calls `sendDMX()`
- `syncUIFromDMX()` rebuilds UI state from `dmxChannels[]` array (used after preset recall)
- Some channels have special update functions: `updateStrobeChannel()`, `updateColorChannel()`, `updateGoboChannel()`

## Future Extension Points

**Timeline/Sequencer** (Phase 3):
- `Keyframe` class defined but not implemented
- `isRecording`, `isPlaying`, `timeline` variables reserved
- UI space allocated at Y=630

**Multi-Device Support**:
- Currently no DMX start address offset
- To add: create `dmxStartAddress` variable (default: 1)
- Modify `sendDMX()`: `actualChannel = dmxStartAddress + (channel - 1)`
- Add UI input field for address configuration

## Development Notes

- User prefers Korean comments in code
- UI optimization focused on usability: large click areas, clear visual feedback
- Git commits use conventional format with Claude Code attribution
- All slider interactions recently enhanced for easier operation (Nov 2024)
