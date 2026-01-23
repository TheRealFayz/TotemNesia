# TotemNesia

**A comprehensive totem management addon for Shaman in Turtle WoW**

TotemNesia helps Shamans efficiently manage their totems by providing visual feedback, quick-cast functionality, and a clickable notification to recall totems after leaving combat. The addon intelligently tracks all your active totems with a dynamic tracker bar, provides instant access to your favorite totems through a quick-cast bar, and monitors your distance from placed totems. **Never be that Shaman that causes an accidental totem pull again.**

## Features

### Totem Bar (Quick-Cast System)
- **5-slot quick-cast interface** - Instant access to your most-used totems (Fire, Earth, Water, Air) plus weapon enchants
- **Flyout menus** - Icon-only display of all available totems/enchants per element
- **Ctrl-click assignment** - Ctrl-click any totem in the flyout to assign it to a slot
- **Persistent selections** - Your favorite totems are saved between sessions
- **Duration timers** - Shows countdown for active totems and weapon enchants on each slot
- **Flexible layouts** - Horizontal (side-by-side) or Vertical (stacked) orientation
- **Smart flyout positioning** - Up/Down/Left/Right directions that auto-adjust with layout
- **Rich tooltips** - Full spell information on mouseover (mana cost, duration, effects)
- **Independent controls** - Separate lock, hide, and scale settings

### Weapon Enchant Slot (5th Slot)
- **Automatic icon display** - Shows the icon of your currently active weapon enchant
- **Flyout menu** - Access all weapon enchants (Rockbiter, Flametongue, Frostbrand, Windfury)
- **Click-to-cast** - Click enchants in the flyout to apply them
- **Duration timer** - Countdown showing remaining enchant time
- **Timer format:**
  - Above 1 minute: Shows minutes (e.g., "30m", "15m", "1m")
  - Below 1 minute: Shows seconds only (e.g., "59", "30", "1")
- **Display-only slot** - Icon updates automatically when you apply an enchant
- **Hide option** - "Hide Weapon Enchant Slot" checkbox to hide just this slot if desired

### Sequential Totem Casting (v4.0+)
- **Keybind support** - Set up a keybind in ESC > Key Bindings > TotemNesia
- **Cycles through totems** - Press once to cast Fire, press again for Earth, then Water, then Air
- **Auto-reset** - Resets to Fire totem after 5 seconds of inactivity
- **Uses assigned totems** - Casts whichever totems you've assigned to your Totem Bar slots
- **One spell per keypress** - Respects Vanilla WoW API limitations

### Distance Tracking
- **Automatic alerts** - UI pops up when you move more than 30 yards from your totems
- **Works in combat** - Prevents totem loss during mobile fights
- **Smart monitoring** - Checks distance every 0.5 seconds without impacting performance

### Totem Tracker Bar
- **Real-time totem display** - Shows icons of all currently active totems
- **Duration timers** - Each totem displays countdown showing time remaining
- **Automatic updates** - Icons appear when totems are placed, disappear when they expire or are recalled
- **Flexible layouts** - Horizontal or Vertical orientation
- **Elemental indicators** - 16x16 pixel indicators positioned to match in-game totem layout
- **Compact design** - 20x20 pixel icons with minimal spacing
- **Smart visibility** - Only shows when you have active totems
- **Fully customizable** - Drag to position, lock in place, hide completely, or scale to preference

### Totemic Recall Notification
- **Clickable interface** - Click the icon to instantly recall all totems
- **Keybind support** - Create a macro to recall totems with a hotkey
- **Countdown timer** - Adjustable 15-60 second countdown before auto-hide
- **Elemental indicators** - Small corner icons show which element totems are active
  - Fire (top-left), Earth (top-right), Air (bottom-left), Water (bottom-right)
- **Combat-aware** - Automatically hides when you re-enter combat
- **Audio notification** - Optional sound alert when notification appears
- **Scalable** - Adjust size from 50% to 200%

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

**Note for v4.0+:** The addon now includes a `Bindings.xml` file for keybind support. Make sure all files are extracted.

## How It Works

### Totem Bar Quick-Cast
1. Mouse over any slot (Fire, Earth, Water, Air, or Weapon) to see the flyout menu
2. **Ctrl-click** a totem in the flyout to assign it to that slot (totems only, not weapon enchants)
3. **Click** the assigned slot anytime to instantly cast that totem
4. **Weapon slot** - Click enchants in the flyout to apply them; icon appears automatically
5. Duration timer appears on the slot when that totem/enchant is active
6. Your totem selections are saved and persist between sessions

### Sequential Totem Casting (v4.0+)
1. Go to ESC > Key Bindings > scroll to "TotemNesia"
2. Bind "Sequential Totem Cast" to your preferred key
3. Press the key once to cast your Fire totem
4. Press again to cast Earth, then Water, then Air
5. If you wait more than 5 seconds, it resets to Fire
6. Only works with totems you've assigned to Totem Bar slots

### Distance Monitoring
1. Totems are tracked when you cast them
2. Every 0.5 seconds, the addon checks your distance from your totems
3. If you move more than 30 yards away, the recall UI automatically appears
4. Works even during combat to help with mobile fights

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
- **Enable Totem Bar** - Toggle the quick-cast bar on/off
- **Lock Totem Bar** - Lock/unlock the totem bar for positioning
- **Hide Totem Bar** - Hide the quick-cast bar if not needed
- **Hide Weapon Enchant Slot** - Hide just the weapon enchant slot if you don't want it
- **Debug mode** - Enable detailed logging for troubleshooting

### Will be enabled when in
- **Solo** - Enable/disable addon when playing solo
- **Parties** - Enable/disable addon when in a 5-man party
- **Raids** - Enable/disable addon when in a raid group

### Layout Controls
- **Totem Bar Layout** - Toggle between Horizontal and Vertical orientation
- **Flyout Direction** - Choose Up/Down (horizontal layout) or Left/Right (vertical layout)

### Display Duration Slider
- Adjust how long the Totemic Recall icon stays visible (15-60 seconds)
- Move the slider to your preferred duration
- Setting saves automatically

### Scale Sliders
- **UI Frame Scale** - Resize the Totemic Recall icon (0.5x to 2.0x)
- **Totem Tracker Scale** - Resize the totem tracking bar (0.5x to 2.0x)
- **Totem Bar Scale** - Resize the quick-cast bar (0.5x to 2.0x)
- All changes preview in real-time

### Keybinds
- **Sequential Totem Cast** (v4.0+) - Available in ESC > Key Bindings > TotemNesia
- **Totemic Recall Macro** - Copy the macro from settings menu to create a hotkey for recalling totems

## Usage Tips

### First Time Setup
1. Type `/tn` to open the options menu
2. Uncheck "Lock UI Frame" to unlock the Totemic Recall icon
3. Drag the icon to your preferred location
4. Repeat for the totem tracker bar with "Lock Totem Tracker"
5. Repeat for the totem bar with "Lock Totem Bar"
6. Adjust layout options (Horizontal/Vertical) to fit your UI
7. Set flyout direction to avoid screen edges
8. Adjust scale sliders to your preference
9. Re-check all lock options when positioned correctly
10. Adjust the display duration slider to your preference

### Setting Up Quick-Cast Totems
1. Place the Totem Bar where you want it (unlock, drag, then lock)
2. Choose your preferred layout (Horizontal or Vertical)
3. Mouse over each slot to see available totems
4. **Ctrl-click** your most-used totems to assign them to slots
5. Click the slots anytime to instantly cast those totems
6. Your selections are automatically saved

### Using the Weapon Enchant Slot
1. Mouse over the 5th slot (weapon slot) to see the flyout
2. Click any enchant to apply it (Rockbiter, Flametongue, Frostbrand, Windfury)
3. The icon automatically appears showing your active enchant
4. Timer counts down: "30m" → "1m" → "59" → "1"
5. Icon clears when enchant expires
6. **Note:** Icon won't show on login/reload for existing enchants (API limitation)

### Using Sequential Totem Casting (v4.0+)
1. Assign your preferred totems to Totem Bar slots (Ctrl-click in flyouts)
2. Go to ESC > Key Bindings > TotemNesia section
3. Bind "Sequential Totem Cast" to a key
4. Press key 4 times to drop all 4 totems (Fire → Earth → Water → Air)
5. If interrupted, wait 5+ seconds and it resets to Fire

### Understanding the Totem Tracker
- **Automatic**: Shows icons of currently active totems only
- **No configuration needed**: Just drop totems and they appear
- **Position anywhere**: Unlock and drag to your preferred location
- **Choose orientation**: Horizontal or Vertical layout options
- **Hide if desired**: Check "Hide Totem Tracker" if you prefer the elemental indicators only
- **Scale it**: Adjust size from 50% to 200%

### Group Type Controls
Use the "Will be enabled when in" checkboxes to control when the addon is active:
- Uncheck "Solo" to disable when not in a group
- Uncheck "Parties" to disable in 5-man groups
- Uncheck "Raids" to disable in raid groups
- All options are enabled by default

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
- Distance warnings
- Weapon enchant detection and timing
- Sequential totem casting (v4.0+)

This is useful for troubleshooting or understanding how the addon tracks your totems.

## Technical Details

### Why Click Instead of Automatic?
Vanilla WoW (1.12) has API restrictions that prevent addons from automatically casting spells outside of combat without player input. TotemNesia works around this by:
- Detecting active totems via combat log parsing
- Providing a clickable UI element that counts as player-initiated input
- Allowing you to recall totems with a single click instead of manually casting
- Helping keep Shamans from forgetting their totems and causing accidental pulls

### Weapon Enchant Detection
The weapon enchant system uses `GetWeaponEnchantInfo()` API to detect active enchants and their expiration times. Because weapon enchants don't show as scannable buffs in Vanilla WoW, the addon tracks which enchant you clicked in the flyout menu and displays that icon while the timer is active. If you reload or login with an existing enchant, the timer will work but the icon won't appear until you apply a fresh enchant from the flyout.

### Sequential Totem Casting (v4.0+)
The sequential casting feature respects Vanilla WoW's "one spell per keypress" limitation. Each keypress casts one totem in order (Fire → Earth → Water → Air). The addon tracks which totem is next and automatically resets to Fire after 5 seconds of inactivity. This feature requires the `Bindings.xml` file to be present for keybind registration.

### Totem Detection Method
The addon tracks totems through multiple combat log events:
- `CHAT_MSG_SPELL_SELF_BUFF` - Detects when totems are cast
- `CHAT_MSG_SPELL_AURA_GONE_SELF` - Detects when totem buffs fade
- `CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE` - Detects when totems die or expire

Individual totems are tracked in the `activeTotems` table, which is used to:
- Power the totem tracker bar display
- Determine which elemental indicators to show
- Decide when to show the Totemic Recall notification
- Monitor distance from placed totems

The totem flag resets when:
- You click to recall totems (Totemic Recall is cast)
- All individual totems expire or are destroyed
- Totemic Recall buff fades

### Frame Positioning
All UI elements can be positioned independently:
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
- Verify the addon is enabled for your current group type (Solo/Parties/Raids)
- Check if distance tracking triggered it earlier (it may have already shown)

**The weapon enchant icon doesn't show**
- Apply a weapon enchant from the flyout menu (icon only appears after using the flyout)
- Check that "Hide Weapon Enchant Slot" is not enabled
- Enable debug mode to see weapon enchant detection messages
- Note: Icon won't show on login/reload for existing enchants (API limitation)

**The weapon enchant timer is wrong**
- Timer uses the game's API and should be accurate
- Enable debug mode to see "Weapon enchant detected, expires in X seconds"
- Try `/reload` if the timer seems stuck

**Sequential totem casting doesn't work (v4.0+)**
- Make sure you have totems assigned to Totem Bar slots (Ctrl-click in flyouts)
- Check ESC > Key Bindings > TotemNesia to verify keybind is set
- Enable debug mode to see "Sequential cast: [element] - [totem name]"
- If it says "No totem assigned", you need to assign totems to slots first

**Sequential cast keeps resetting to Fire**
- This is normal if you wait more than 5 seconds between presses
- The auto-reset prevents confusion when you come back later
- Press the key 4 times quickly to drop all totems

**The totem tracker isn't showing my totems**
- Make sure "Hide Totem Tracker" is unchecked in options
- Enable debug mode to see what totems are being tracked
- Verify the totems are actually active (some expire quickly)

**Totem tracker shows wrong totems**
- This shouldn't happen, but enable debug mode to see what's being tracked
- The addon parses combat log messages - make sure you're seeing totem cast messages
- Try `/reload` to reset

**The flyout menus won't open**
- Make sure you're mousing over the actual slot, not the space between slots
- Check that "Hide Totem Bar" is not enabled
- Try `/reload` if menus seem stuck

**Ctrl-click doesn't assign totems**
- Make sure you're holding Ctrl while clicking
- Ctrl-click does NOT work for weapon enchants (they're click-to-cast only)
- Enable debug mode to see if assignment is being detected
- Try `/reload` and reassign

**Tooltips don't show or show incorrect information**
- Make sure you have the totem spell learned in your spellbook
- Some totems may not have proper tooltip data - this is normal
- Enable debug mode if you see errors

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

**The addon isn't working in my group**
- Check the "Will be enabled when in" settings
- Make sure the checkbox for your current group type (Solo/Parties/Raids) is checked
- All options are enabled by default

**Distance alerts trigger too often/not often enough**
- Distance threshold is set at 30 yards (standard totem range)
- This is working as intended to prevent range loss
- If you're frequently moving in combat, alerts help you reposition totems

## Contributing

Found a bug or have a feature request? Please submit an issue on the GitHub repository.

## License

This addon is provided as-is for use with Turtle WoW.  If you wish to make edits or forks to the code, please feel free to reach out. 

## Credits

Created for the Turtle WoW community to help Shamans manage their totems more efficiently.

Special thanks to all the beta testers and community members who provided feedback during development.

---

**Enjoy your enhanced totem management, and may your totems always be where you need them!**
