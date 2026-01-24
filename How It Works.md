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

### Totem Sets (v3.4+)
1. Open settings (`/tn`) and click the "Totem Sets" tab
2. Use the numbered buttons (1-5) at the top to select which set to configure
3. Click any totem icon to assign it to the currently selected set
4. Gold borders show which totems are assigned to the active set
5. Go to ESC > Key Bindings > TotemNesia
6. Bind "Totem Set 1" through "Totem Set 5" to your preferred keys
7. Press a keybind to cast that set's totems:
   - **With nampower**: All 4 totems cast instantly with one keypress
   - **Without nampower**: Spam the key 4 times to cast Fire→Earth→Water→Air in sequence
8. Switch between sets using the numbered buttons to configure different combinations

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