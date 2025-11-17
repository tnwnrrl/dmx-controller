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
- Window: 1400x800px
- DMX Monitor: Y=480, Height=140px
- Timeline: Y=630, Height=120px
- Presets: Y=710
- Tab content starts: Y=110
- Standard margin: 30px

**State Synchronization**:
- `updateDMXChannel(channel, value)` updates array and calls `sendDMX()`
- `syncUIFromDMX()` rebuilds UI state from `dmxChannels[]` array (used after preset recall)
- Some channels have special update functions: `updateStrobeChannel()`, `updateColorChannel()`, `updateGoboChannel()`

## Phase 3: Video Timeline Sequencer

**IMPLEMENTED** - The video timeline system is fully operational with keyframe-based DMX sequencing.

### Core Architecture

**Video Integration**:
- Uses Processing's `Movie` class for video playback
- Video file: `data/video.mp4` (hardcoded path)
- `movieEvent(Movie m)` callback reads frames at ~60 FPS
- Timeline synchronized to video time via `movie.time()`

**Keyframe System**:
- `Keyframe` class stores: `timestamp` (float seconds), `dmxValues[]` (18 channels), `interpolateToNext` (boolean)
- `timeline` ArrayList maintains chronologically sorted keyframes
- Keyframes persist to `data/sequence.json` with JSON serialization

**Playback Modes**:
1. **Instant Switching (default)**: Keyframe values held constant until next keyframe
2. **Interpolation**: When `interpolateToNext=true`, linear fade to next keyframe
   - Uses `interpolateKeyframes(kf1, kf2, t)` for smooth transitions
   - Only sends changed DMX channels (performance optimization)

**DMX Performance Optimization**:
- `applyKeyframe()` and `interpolateKeyframes()` only send changed channels
- Prevents serial buffer overflow (was 1,080 commands/sec, now 80-95% reduction)
- Critical for 60 FPS video playback without stuttering

### User Workflow

**Keyframe Creation**:
1. Play/pause video with spacebar or playback controls
2. Adjust DMX channels via UI (any tab)
3. Press **K key** to capture current state as keyframe
   - Auto-saves to `data/sequence.json`
   - Keyframe appears as triangle marker on timeline

**Keyframe Editing**:
1. Click keyframe marker (triangle) to select (turns orange)
2. Keyframe info panel shows all 18 channel values
3. Adjust any DMX channel - values update in real-time
4. Press **S key** or click "💾 Save" button to persist changes
   - `hasUnsavedChanges` flag tracks dirty state
   - Only keyframe edits require manual save (K/Delete auto-save)

**Keyframe Deletion**:
- Select keyframe, press **Delete/Backspace**
- Auto-saves after deletion

**Interpolation Toggle**:
- Select keyframe, click "⚡ Instant" or "🔄 Fade" button
- Visual indicator: Green markers = instant, Blue markers = interpolation
- Selected keyframe always shows orange

**Timeline Navigation**:
- Click seekbar to jump to time (applies nearest keyframe values)
- Click keyframe marker to jump and select
- Seekbar shows video position, progress bar, and keyframe markers

### Key Functions

**Timeline Sync**:
- `updateDMXFromTimeline()` - Called every frame during playback
  - Finds active keyframe (most recent before current time)
  - Checks `interpolateToNext` flag
  - Applies instant or interpolated values

**Keyframe Operations**:
- `addKeyframe()` - Captures current DMX state at video time
- `deleteSelectedKeyframe()` - Removes selected keyframe
- `applyKeyframe(kf)` - Sets DMX channels from keyframe (delta-only)
- `interpolateKeyframes(kf1, kf2, t)` - Linear blend between keyframes

**Persistence**:
- `saveSequence(filename)` - JSON export with all keyframe data
- `loadSequence(filename)` - Loads on startup, backward compatible
- Format: `[{timestamp, dmxValues[], interpolateToNext}, ...]`

### Timeline Controls

**Playback**:
- Stop (■) - Reset to start, stop playback
- Play (▶) - Start/resume playback
- Pause (⏸) - Pause at current position
- Spacebar - Toggle play/pause

**Keyboard Shortcuts**:
- **K** - Add keyframe at current time
- **S** - Save keyframe changes (when keyframe selected)
- **Delete/Backspace** - Delete selected keyframe
- **Spacebar** - Play/pause toggle

### Visual Indicators

**Keyframe Markers** (triangles above seekbar):
- Orange = Selected keyframe
- Blue = Interpolation mode enabled
- Green = Instant switching mode

**Keyframe Info Panel** (shown when keyframe selected):
- Displays all 18 channel values (3 rows of 6 channels)
- Interpolation toggle button
- Save button with unsaved changes indicator

### Technical Notes

- Timeline area: 120px height (expanded from original 60px)
- Keyframe markers: 16px triangles (doubled from 8px for easier clicking)
- Click detection: 10px tolerance around markers
- Video preview: 80x60px thumbnail at Y=630
- Sequence file updates only on K press, Delete, or S key (not on slider changes)

## Future Extension Points

**Multi-Device Support**:
- Currently no DMX start address offset
- To add: create `dmxStartAddress` variable (default: 1)
- Modify `sendDMX()`: `actualChannel = dmxStartAddress + (channel - 1)`
- Add UI input field for address configuration

**Video Path Configuration**:
- Currently hardcoded to `data/video.mp4`
- Consider adding file picker or config file for video path

## Development Notes

- User prefers Korean comments in code
- UI optimization focused on usability: large click areas, clear visual feedback
- Git commits use conventional format with Claude Code attribution
- Phase 3 video timeline completed November 2024 with full interpolation support
