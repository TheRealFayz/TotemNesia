# TotemNesia

**A comprehensive totem management addon for Shaman in Turtle WoW**

TotemNesia helps Shamans efficiently manage their totems by providing visual feedback, quick-cast functionality, and a clickable notification to recall totems after leaving combat. The addon intelligently tracks all your active totems with a dynamic tracker bar, provides instant access to your favorite totems through a quick-cast bar, and monitors your distance from placed totems. **Never be that Shaman that causes an accidental totem pull again.**

## Features

### Totem Bar (Quick-Cast System)
- **5-slot quick-cast interface** - Instant access to your most-used totems (Fire, Earth, Water, Air) plus weapon enchants
- **Flyout menus** - Mouse over slots to see all available totems/enchants with tooltips
- **Ctrl-click assignment** - Assign your favorite totems to slots (saved between sessions)
- **Duration timers** - Shows countdown for active totems and weapon enchants
- **Flexible layouts** - Horizontal or Vertical orientation with smart flyout positioning
- **Independent controls** - Separate lock, hide, and scale settings
<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/Totem%20Bar%20Closed.png?raw=true">

<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/Totem%20Bar.png?raw=true">

### Weapon Enchant Slot (5th Slot)
- **Automatic icon display** - Shows your currently active weapon enchant
- **Flyout menu** - Access all weapon enchants (Rockbiter, Flametongue, Frostbrand, Windfury)
- **Click-to-cast** - Click enchants in the flyout to apply them
- **Duration timer** - Countdown in minutes (30m, 1m) or seconds (59, 30, 1) when under 1 minute
- **Hide option** - Optional checkbox to hide this slot if not needed

### Totem Casting (v4.0+)
- **Keybind support** - Set up a keybind in ESC > Key Bindings > TotemNesia
- **Nampower detection** - Automatically detects nampower client mod for instant 4-totem casting
- **Adaptive casting modes:**
  * **With nampower**: Press keybind once to instantly cast all 4 totems (Fire, Earth, Water, Air)
  * **Without nampower**: Spam keybind to cycle through totems sequentially (one per keypress)
- **Auto-reset** - Resets to Fire totem after 5 seconds of inactivity (non-nampower mode)
- **Uses assigned totems** - Casts whichever totems you've assigned to your Totem Bar slots

<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/1%20button%20totems.gif?raw=true">

### Totem Sets (v3.4+)
- **5 configurable sets** - Create up to 5 different totem combinations for various situations
- **Visual assignment interface** - Click totems to assign one from each family (Fire, Earth, Water, Air) to each set
- **Gold border highlighting** - Selected totems show a gold border for easy identification
- **Quick-switch selector** - Buttons to switch between sets instantly
- **Individual keybinds** - Set up separate keybinds for each of the 5 totem sets
- **Nampower detection** - Automatically detects nampower client mod for enhanced functionality
- **Adaptive casting modes:**
  * **With nampower**: Press keybind once to instantly cast all 4 totems from that set
  * **Without nampower**: Spam keybind to cast totems sequentially (Fire→Earth→Water→Air)
- **Persistent storage** - All set configurations saved between sessions

### Distance Tracking
- **Automatic alerts** - UI pops up when you move more than 30 yards from your totems
- **Works in combat** - Prevents totem loss during mobile fights
- **Smart monitoring** - Checks distance every 0.5 seconds without impacting performance

### Totem Tracker Bar
- **Real-time totem display** - Shows icons and duration timers for all currently active totems
- **Automatic updates** - Icons appear when totems are placed, disappear when they expire or are recalled
- **Flexible layouts** - Horizontal or Vertical orientation with 20x20 pixel icons
- **Elemental indicators** - 16x16 pixel indicators positioned to match in-game totem layout
- **Fully customizable** - Drag to position, lock in place, hide completely, or scale from 50% to 200%

### Totemic Recall Notification
- **Clickable interface** - Click the icon to instantly recall all totems
- **Keybind support** - Create a macro to recall totems with a hotkey
- **Countdown timer** - Adjustable 15-60 second countdown before auto-hide
- **Elemental indicators** - Small corner icons show which element totems are active
  - Fire (top-left), Earth (top-right), Air (bottom-left), Water (bottom-right)
- **Combat-aware** - Automatically hides when you re-enter combat
- **Audio notification** - Optional sound alert when notification appears
- **Scalable** - Adjust size from 50% to 200%

<img src="https://github.com/TheRealFayz/TotemNesia/blob/main/Images/Totemic%20Recall.png?raw=true">

### Smart Detection
- **Combat log tracking** - Monitors individual totem summons and expirations
- **Fire Nova handling** - Intelligently ignores self-destructing Fire Nova Totems
- **Element categorization** - Automatically identifies Fire, Water, Earth, and Air totems
- **Efficient updates** - All visual elements update every 0.5 seconds

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

### Totem Sets and Nampower Detection (v3.4+)
The totem sets system stores 5 independent configurations in `TotemNesiaDB.totemSets`, each containing one totem from each family. On login, the addon attempts to call `GetNampowerVersion()` to detect if the nampower client mod is installed. If detected, keybinds cast all 4 totems instantly by calling `CastSpellByName()` for each totem in sequence. Without nampower, the system uses the same sequential casting logic as v4.0, requiring the player to spam the keybind to cycle through all 4 totems. A 10-second inactivity timeout automatically resets the sequence to Fire totem.

## Contributing

Found a bug or have a feature request? Please submit an issue on the GitHub repository.

## License

This addon is provided as-is for use with Turtle WoW.  If you wish to make edits or forks to the code, please feel free to reach out. 

## Credits

Special thanks to all the beta testers and community members who provided feedback during development.

**Enjoy your enhanced totem management, and may your totems always be where you need them!**
