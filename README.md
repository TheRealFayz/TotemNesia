# TotemNesia

**A comprehensive totem management addon for Shaman in Turtle WoW**

TotemNesia helps Shamans efficiently manage their totems by providing visual feedback and a clickable notification to recall totems after leaving combat. The addon intelligently tracks all your active totems with a dynamic tracker bar and elemental indicators, while prompting you to recall when needed. **Never be that Shaman that causes an accidental totem pull again.**

## Features

### Totem Tracker Bar
- **Real-time totem display** - Shows icons of all currently active totems
- **Duration timers** - Each totem displays countdown showing time remaining
- **Automatic updates** - Icons appear when totems are placed, disappear when they expire or are recalled
- **Compact design** - 20x20 pixel icons with minimal spacing
- **Smart visibility** - Only shows when you have active totems
- **Fully customizable** - Drag to position, lock in place, or hide completely

### Totemic Recall Notification
- **Clickable interface** - Click the icon to instantly recall all totems
- **Keybind support** - Create a macro to recall totems with a hotkey
- **Countdown timer** - Adjustable 15-60 second countdown before auto-hide
- **Elemental indicators** - Small corner icons show which element totems are active
  - Fire (top-left), Earth (top-right), Air (bottom-left), Water (bottom-right)
- **Combat-aware** - Automatically hides when you re-enter combat
- **Audio notification** - Optional sound alert when notification appears

### Smart Detection
- **Combat log tracking** - Monitors individual totem summons and expirations
- **Fire Nova handling** - Intelligently ignores self-destructing Fire Nova Totems
- **Element categorization** - Automatically identifies Fire, Water, Earth, and Air totems
- **Efficient updates** - All visual elements update every 0.5 seconds

## Installation

1. Download the addon files
2. Extract the `TotemNesia` folder to your `World of Warcraft\Interface\AddOns\` directory
3. Restart WoW or type `/reload` in-game
4. The addon will automatically load when you log in with a Shaman character

## How It Works

### During Combat
1. TotemNesia tracks every totem you cast through combat log monitoring
2. The totem tracker bar shows all active totems with their actual spell icons and duration timers
3. Elemental indicators on the Totemic Recall icon show which types are active

### After Combat
1. When you leave combat with active totems, the Totemic Recall icon appears
2. The icon displays a countdown timer (default 15 seconds, customizable up to 60)
3. Click the icon to instantly cast Totemic Recall
4. The totem tracker bar continues to show active totems until they're recalled or expire

![Totem Tracker and Recall Interface](https://github.com/TheRealFayz/TotemNesia/blob/main/Images/Totemic%20Recall.png)

## Options Menu

Access all settings by clicking the minimap button, or typing `/tn`:

### Settings
- **Lock UI Frame** - Lock/unlock the Totemic Recall icon for positioning
- **Mute audio queue** - Toggle audio notifications on/off
- **Hide UI element** - Hide the Totemic Recall icon (audio-only mode for experienced players)
- **Lock Totem Tracker** - Lock/unlock the totem tracker bar for positioning
- **Hide Totem Tracker** - Completely hide the totem tracker if you prefer not to use it
- **Debug mode** - Enable detailed logging for troubleshooting

### Display Duration Slider
- Adjust how long the Totemic Recall icon stays visible (15-60 seconds)
- Move the slider to your preferred duration
- Setting saves automatically

### Keybind Macro
- Click the macro text at the bottom of the options menu to select it
- Press Ctrl+C to copy
- Create a WoW macro with this command and bind it to a key
- Allows you to recall totems with a hotkey instead of clicking the UI

## Usage Tips

### First Time Setup
1. Type `/tn` to open the options menu
2. Uncheck "Lock UI Frame" to unlock the Totemic Recall icon
3. Drag the icon to your preferred location
4. Re-check "Lock UI Frame" to lock it in place
5. Repeat for the totem tracker bar with "Lock Totem Tracker"
6. Adjust the display duration slider to your preference

### Understanding the Totem Tracker
- **Automatic**: Shows icons of currently active totems only
- **No configuration needed**: Just drop totems and they appear
- **Position anywhere**: Unlock and drag to your preferred location
- **Hide if desired**: Check "Hide Totem Tracker" if you prefer the elemental indicators only

### Audio-Only Mode
For experienced players who want minimal UI:
1. Check "Hide UI element" in options
2. You'll still get the audio cue after combat
3. The totem tracker (if enabled) will still show your active totems
4. Manually cast Totemic Recall when ready

### Debug Mode
Enable debug mode in the options menu to see detailed information about:
- When individual totems are summoned
- When totems fade or die
- Combat state changes
- Totem recall events
- Element categorization

This is useful for troubleshooting or understanding how the addon tracks your totems.

## Technical Details

### Why Click Instead of Automatic?
Vanilla WoW (1.12) has API restrictions that prevent addons from automatically casting spells outside of combat without player input. TotemNesia works around this by:
- Detecting active totems via combat log parsing
- Providing a clickable UI element that counts as player-initiated input
- Allowing you to recall totems with a single click instead of manually casting
- Helping keep Shamans from forgetting their totems and causing accidental pulls

### Totem Detection Method
The addon tracks totems through multiple combat log events:
- `CHAT_MSG_SPELL_SELF_BUFF` - Detects when totems are cast
- `CHAT_MSG_SPELL_AURA_GONE_SELF` - Detects when totem buffs fade
- `CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE` - Detects when totems die or expire

Individual totems are tracked in the `activeTotems` table, which is used to:
- Power the totem tracker bar display
- Determine which elemental indicators to show
- Decide when to show the Totemic Recall notification

The totem flag resets when:
- You click to recall totems (Totemic Recall is cast)
- All individual totems expire or are destroyed
- Totemic Recall buff fades

### Frame Positioning
Both UI elements can be positioned independently:
- **Unlocked**: Frames have higher opacity and can be dragged
- **Locked**: Frames are semi-transparent and clickable (for Totemic Recall icon)
- All positions are preserved between sessions

## Troubleshooting

**The Totemic Recall icon appears but nothing happens when I click it**
- Make sure "Lock UI Frame" is checked in options
- Enable debug mode and check for error messages
- Verify you have Totemic Recall learned

**The icon shows even when I don't have totems**
- Enable debug mode to see when the addon detects totems
- Make sure you're running the latest version.
- Try `/reload` to reset the addon state

**The icon doesn't appear after combat**
- Verify you actually placed totems during or before combat
- Enable debug mode to see if totems are being detected
- Check if "Hide UI element" is enabled in options

**The totem tracker isn't showing my totems**
- Make sure "Hide Totem Tracker" is unchecked in options
- Enable debug mode to see what totems are being tracked
- Verify the totems are actually active (some expire quickly)

**Totem tracker shows wrong totems**
- This shouldn't happen, but enable debug mode to see what's being tracked
- The addon parses combat log messages - make sure you're seeing totem cast messages
- Try `/reload` to reset

**I can't move the frames**
- Open options (`/tn`) and uncheck the appropriate lock option
- Make sure you're dragging from the frame itself
- Try `/reload` if frames seem stuck

**The Totemic Recall icon doesn't hide when I re-lock it**
- This is expected if you have an active countdown timer running
- The icon will hide once the timer expires or you leave combat without totems
- You can also hide it by checking "Hide UI element"

**The elemental indicators don't match my totems**
- Enable debug mode to see how totems are being categorized
- Make sure you're using the standard totem names (not renamed by other addons)
- Some totems may be categorized unexpectedly - report these as bugs

## Contributing

Found a bug or have a feature request? Please submit an issue on the GitHub repository.

## License

This addon is provided as-is for use with Turtle WoW.

## Credits

Created for the Turtle WoW community to help Shamans manage their totems more efficiently.

Special thanks to all the beta testers and community members who provided feedback during development.

---

**Enjoy your enhanced totem management, and may your totems always be where you need them!**
